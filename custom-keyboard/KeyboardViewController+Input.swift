import UIKit
import os.log

private let inputModeLogger = OSLog(
  subsystem: "com.nijoow.keyboard", category: "input-mode")

enum KeyboardActionFeedback {
  case keyPress
  case repeatCursor
  case repeatBackspace
  case none
}

extension KeyboardViewController {

  // MARK: - 단일 입력 액션 경로

  func keyboardAction(for keyValue: String) -> KeyboardAction? {
    switch keyValue {
    case KeyboardConstants.KeyID.shift: return .shift
    case KeyboardConstants.KeyID.backspace: return .backspace
    case KeyboardConstants.KeyID.language: return .switchLanguage
    case KeyboardConstants.KeyID.symbol: return .toggleSymbols
    case KeyboardConstants.KeyID.enter: return .enter
    case KeyboardConstants.KeyID.custom: return .toggleEmoji
    case KeyboardConstants.KeyID.dismiss: return .dismiss
    case KeyboardConstants.KeyID.nextKeyboard: return .nextKeyboard
    case KeyboardConstants.KeyID.space: return .space
    case KeyboardConstants.KeyID.cursorLineStart: return .moveCursor(.lineStart)
    case KeyboardConstants.KeyID.cursorLeft: return .moveCursor(.left)
    case KeyboardConstants.KeyID.cursorRight: return .moveCursor(.right)
    case KeyboardConstants.KeyID.cursorLineEnd: return .moveCursor(.lineEnd)
    case KeyboardConstants.KeyID.dummy, "": return nil
    default: return .character(keyValue)
    }
  }

  @discardableResult
  func dispatchKeyboardAction(
    _ action: KeyboardAction, feedback: KeyboardActionFeedback = .keyPress
  ) -> Bool {
    synchronizeInputDocument()
    if action != .shift && action != .lockShift {
      interactionState.cancelShiftTapCandidate()
    }

    let didPerform: Bool
    switch action {
    case .character(let key):
      didPerform = handleCharacterInput(key)
    case .shift:
      interactionState.tapShift(
        at: ProcessInfo.processInfo.systemUptime,
        doubleTapInterval: KeyboardConstants.Interaction.shiftDoubleTapInterval)
      rebuildKeyboard()
      didPerform = true
    case .lockShift:
      let previous = interactionState
      interactionState.lockShift()
      if interactionState != previous { rebuildKeyboard() }
      didPerform = interactionState != previous
    case .backspace:
      didPerform = handleBackspace()
    case .moveCursor(let movement):
      flushHangul()
      didPerform = handleCursorMove(movement)
    case .space:
      flushHangul()
      performDocumentMutation { insertTextThroughProxy(KeyboardConstants.KeyID.space) }
      didPerform = true
    case .switchLanguage:
      flushHangul()
      interactionState.toggleLanguage()
      UserDefaults.standard.set(isHangul, forKey: KeyboardConstants.Storage.hangulMode)
      rebuildKeyboard()
      didPerform = true
    case .toggleSymbols:
      flushHangul()
      if inputLayout == .number {
        showsNumericSymbols.toggle()
        updateNumericKeyLabels()
      } else {
        interactionState.toggleSymbols()
        rebuildKeyboard()
      }
      didPerform = true
    case .toggleEmoji:
      flushHangul()
      interactionState.toggleEmoji()
      rebuildKeyboard()
      didPerform = true
    case .enter:
      flushHangul()
      performDocumentMutation { insertTextThroughProxy("\n") }
      didPerform = true
    case .dismiss:
      flushHangul()
      os_log(
        "Keyboard dismiss requested by keyboard control", log: inputModeLogger, type: .default)
      dismissKeyboard()
      didPerform = true
    case .nextKeyboard:
      flushHangul()
      os_log(
        "Next input mode requested by keyboard control", log: inputModeLogger, type: .default)
      advanceToNextInputMode()
      didPerform = true
    }

    guard didPerform else { return false }
    markSuccessfulAction(feedback: feedback)
    return true
  }

  func markSuccessfulAction(feedback: KeyboardActionFeedback) {
    inputMutationGeneration &+= 1
    KeyboardInputDiagnostics.shared.recordInputAction()
    switch feedback {
    case .keyPress: KeyboardHaptics.shared.playKeyPress()
    case .repeatCursor: KeyboardHaptics.shared.playRepeat(.cursor)
    case .repeatBackspace: KeyboardHaptics.shared.playRepeat(.backspace)
    case .none: break
    }
  }

  // MARK: - 문자 및 한글 입력 로직

  @discardableResult
  func handleCharacterInput(_ key: String) -> Bool {
    guard let ch = key.first else { return false }

    if isHangul && ch.isLetter && !isSymbol && !inputLayout.isNumeric {
      inputHangul(ch)
    } else {
      flushHangul()
      performDocumentMutation {
        let toInsert = (ch.isLetter && isShifted && !isSymbol) ? key.uppercased() : key
        insertTextThroughProxy(toInsert)
      }
    }

    // 글자 입력 후 일회용 시프트 해제 (심볼 모드가 아닐 때만)
    if interactionState.consumeOneShotShift() {
      rebuildKeyboard()
    }
    return true
  }

  func inputHangul(_ ch: Character) {
    let jamo: Character
    if isShifted, let shifted = KeyboardConstants.hangulShiftMap[ch] {
      jamo = shifted
    } else if let hangul = KeyboardConstants.hangulMap[ch] {
      jamo = hangul
    } else {
      flushHangul()
      performDocumentMutation {
        insertTextThroughProxy(String(ch))
      }
      return
    }

    performDocumentMutation {
      automata.input(jamo)
      renderComposing()
    }
  }

  /// 변경 전 입력 방식: 공통 접두사를 보존하고 바뀐 꼬리만 삭제·삽입한다.
  /// OS의 marked 범위는 사용하지 않는다.
  func renderComposing() {
    let newComposed = automata.compose()
    let common = commonPrefixCount(composedText, newComposed)
    let deleteCount = composedText.count - common
    for _ in 0..<deleteCount { deleteBackwardThroughProxy() }
    let insertPart = String(newComposed.dropFirst(common))
    if !insertPart.isEmpty { insertTextThroughProxy(insertPart) }
    composedText = newComposed
  }

  func commonPrefixCount(_ a: String, _ b: String) -> Int {
    var count = 0
    var i = a.startIndex
    var j = b.startIndex
    while i < a.endIndex, j < b.endIndex, a[i] == b[j] {
      count += 1
      i = a.index(after: i)
      j = b.index(after: j)
    }
    return count
  }

  func flushHangul() {
    // 표시된 글자는 이미 문서에 있으므로 내부 조합만 초기화한다.
    automata.reset()
    composedText = ""
  }

  // MARK: - 기능 키 핸들링

  @objc func shiftTapped() {
    dispatchKeyboardAction(.shift)
  }

  @objc func handleShiftLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      dispatchKeyboardAction(.lockShift)
    }
  }

  @objc func langTapped() {
    dispatchKeyboardAction(.switchLanguage)
  }

  @objc func symbolTapped() {
    dispatchKeyboardAction(.toggleSymbols)
  }

  @objc func enterTapped() {
    dispatchKeyboardAction(.enter)
  }

  // MARK: - 커서 이동 및 가속

  @objc func cursorTouchDown(_ sender: UIButton) {
    guard let id = sender.accessibilityIdentifier,
      let action = keyboardAction(for: id),
      case .moveCursor = action
    else { return }
    dispatchKeyboardAction(action)

    // 왼쪽/오른쪽 버튼인 경우에만 가속 타이머 작동
    if id == KeyboardConstants.KeyID.cursorLeft || id == KeyboardConstants.KeyID.cursorRight {
      cursorRepeatCount = 0
      stopCursorRepeat()
      cursorStartTimer = scheduleInputTimer(
        interval: KeyboardConstants.Interaction.repeatStartDelay, repeats: false
      ) { [weak self] in
        self?.startContinuousCursorMove(id: id)
      }
    }
  }

  @objc func cursorTouchUp(_ sender: UIButton) {
    stopCursorRepeat()
  }

  @discardableResult
  private func handleCursorMove(_ movement: CursorMovement) -> Bool {
    switch movement {
    case .left:
      moveCursorThroughProxy(byCharacterOffset: -1)
    case .right:
      moveCursorThroughProxy(byCharacterOffset: 1)
    case .lineStart:
      let before = textDocumentProxy.documentContextBeforeInput ?? ""
      if before.isEmpty || before.last == "\n" {
        // 이미 줄의 맨 앞이면 이전 줄로 이동
        moveCursorThroughProxy(byCharacterOffset: -1)
      } else {
        // 현재 줄의 맨 앞으로 이동
        if let lastNewline = before.lastIndex(of: "\n") {
          let offset = before.distance(from: lastNewline, to: before.endIndex) - 1
          moveCursorThroughProxy(byCharacterOffset: -offset)
        } else {
          moveCursorThroughProxy(byCharacterOffset: -before.count)
        }
      }
    case .lineEnd:
      let after = textDocumentProxy.documentContextAfterInput ?? ""
      if after.isEmpty || after.first == "\n" {
        // 이미 줄의 맨 뒤면 다음 줄로 이동
        moveCursorThroughProxy(byCharacterOffset: 1)
      } else {
        // 현재 줄의 맨 뒤로 이동
        if let firstNewline = after.firstIndex(of: "\n") {
          let offset = after.distance(from: after.startIndex, to: firstNewline)
          moveCursorThroughProxy(byCharacterOffset: offset)
        } else {
          moveCursorThroughProxy(byCharacterOffset: after.count)
        }
      }
    }
    return true
  }

  private func startContinuousCursorMove(
    id: String, interval: TimeInterval = KeyboardConstants.Interaction.cursorRepeatInterval
  ) {
    cursorTimer?.invalidate()
    cursorTimer = scheduleInputTimer(interval: interval, repeats: true) { [weak self] in
      guard let self else { return }
      guard let action = self.keyboardAction(for: id), case .moveCursor = action else { return }
      self.dispatchKeyboardAction(action, feedback: .repeatCursor)
      self.cursorRepeatCount += 1

      if self.cursorRepeatCount == KeyboardConstants.Interaction.fastRepeatThreshold {
        self.startContinuousCursorMove(
          id: id, interval: KeyboardConstants.Interaction.fastRepeatInterval)
      } else if self.cursorRepeatCount == KeyboardConstants.Interaction.fastestRepeatThreshold {
        self.startContinuousCursorMove(
          id: id, interval: KeyboardConstants.Interaction.fastestRepeatInterval)
      }
    }
  }

  @objc func customTapped() {
    dispatchKeyboardAction(.toggleEmoji)
  }

  @objc func dismissTapped() {
    dispatchKeyboardAction(.dismiss)
  }

  @objc func nextKeyboardTapped() {
    dispatchKeyboardAction(.nextKeyboard)
  }

  // MARK: - 스페이스바 드래그 커서 이동

  @objc func handleSpacePan(_ gesture: UIPanGestureRecognizer) {
    switch gesture.state {
    case .began:
      accumulatedPanX = 0
      gesture.setTranslation(.zero, in: gesture.view)

    case .changed:
      guard isSpaceCursorModeActive else {
        gesture.setTranslation(.zero, in: gesture.view)
        return
      }
      // 이전 실시간 이동량을 누적
      let translation = gesture.translation(in: gesture.view)
      accumulatedPanX += translation.x
      // 처리가 완료된 상대적 증분만 남기기 위해 translation 리셋
      gesture.setTranslation(.zero, in: gesture.view)

      let threshold = KeyboardConstants.Interaction.spaceCursorStep

      // 한 프레임 안에 임계값 여러 칸을 이동해도 남은 거리는 유지하되, 지연 뒤 도착한
      // 이벤트 하나가 문서 프록시 IPC를 무제한 실행해 메인 런루프를 막지는 않게 한다.
      var processedSteps = 0
      while abs(accumulatedPanX) >= threshold,
        processedSteps < KeyboardConstants.Interaction.maxCursorStepsPerPanEvent
      {
        let direction = accumulatedPanX > 0 ? 1 : -1
        let movement: CursorMovement = direction > 0 ? .right : .left
        dispatchKeyboardAction(.moveCursor(movement), feedback: .repeatCursor)

        // 이동한 만큼의 거리를 뺀 나머지만 남겨서 부드러운 연속 이동 가능케 함
        accumulatedPanX -= CGFloat(direction) * threshold
        processedSteps += 1
      }

    case .ended, .cancelled:
      accumulatedPanX = 0

    default:
      break
    }
  }

  // 스페이스바 꾹 누름(롱프레스) → 드래그 없이도 커서 이동 모드로 진입.
  // 짧게 탭하면 롱프레스가 인식되지 않아 touchesEnded에서 띄어쓰기만 입력된다.
  @objc func handleSpaceLongPress(_ gesture: UILongPressGestureRecognizer) {
    switch gesture.state {
    case .began:
      beginSpaceCursorMode()
    case .ended, .cancelled:
      endSpaceCursorMode()
    default:
      break
    }
  }

  /// 커서 이동 모드 진입 (롱프레스/드래그 공통). 현재 한글 조합을 완료해 꼬임 방지.
  func beginSpaceCursorMode() {
    guard !isSpaceCursorModeActive else { return }
    flushHangul()
    interactionState.cancelShiftTapCandidate()
    accumulatedPanX = 0
    shouldSuppressSpaceTap = true
    isSpaceCursorModeActive = true
    beginSpaceDragVisual()
    markSuccessfulAction(feedback: .keyPress)
  }

  /// 커서 이동 모드 종료 (롱프레스/드래그 공통).
  func endSpaceCursorMode() {
    guard isSpaceCursorModeActive || spaceDragOverlay != nil else { return }
    accumulatedPanX = 0
    isSpaceCursorModeActive = false
    endSpaceDragVisual()
  }

  // MARK: - 백스페이스 및 가속 삭제

  @objc func backspaceTouchDown(_ sender: UIButton) {
    beginBackspaceRepeat()
  }

  @objc func backspaceTouchUp(_ sender: UIButton) {
    stopBackspaceRepeat()
  }

  func beginBackspaceRepeat() {
    stopBackspaceRepeat()
    backspaceRepeatCount = 0
    backspaceHoldStartedAt = ProcessInfo.processInfo.systemUptime
    dispatchKeyboardAction(.backspace)
    backspaceStartTimer = scheduleInputTimer(
      interval: KeyboardConstants.Interaction.backspaceRepeatStartDelay, repeats: false
    ) { [weak self] in
      self?.scheduleNextBackspaceTick()
    }
  }

  func stopBackspaceRepeat() {
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
    backspaceStartTimer = nil
    backspaceTimer = nil
    backspaceHoldStartedAt = nil
  }

  func stopCursorRepeat() {
    cursorStartTimer?.invalidate()
    cursorTimer?.invalidate()
    cursorStartTimer = nil
    cursorTimer = nil
  }

  @discardableResult
  private func handleBackspace() -> Bool {
    var didDelete = false
    performDocumentMutation {
      if isHangul && !isSymbol && !inputLayout.isNumeric {
        // 한글 조합 중일 때 (스택에 자모가 남아있음)
        if !automata.jamoStack.isEmpty {
          automata.backspace()
          renderComposing()
          didDelete = true
        } else {
          // 조합 중이 아닐 때 앞 글자(음절) 한 자 삭제
          if textDocumentProxy.hasText {
            deleteBackwardThroughProxy()
            composedText = ""
            didDelete = true
          }
        }
      } else {
        // 영문 또는 기호 모드
        if textDocumentProxy.hasText {
          deleteBackwardThroughProxy()
          didDelete = true
        }
      }
    }
    return didDelete
  }

  private func scheduleNextBackspaceTick() {
    guard let startedAt = backspaceHoldStartedAt else { return }
    backspaceTimer?.invalidate()
    let heldDuration = ProcessInfo.processInfo.systemUptime - startedAt
    let profile = BackspaceRepeatProfile.profile(heldDuration: heldDuration)
    backspaceTimer = scheduleInputTimer(interval: profile.interval, repeats: false) { [weak self] in
      guard let self else { return }
      var deletedCount = 0
      for _ in 0..<profile.batchSize {
        guard self.dispatchKeyboardAction(.backspace, feedback: .none) else { break }
        deletedCount += 1
      }
      guard deletedCount > 0 else {
        self.backspaceTimer = nil
        return
      }
      KeyboardHaptics.shared.playRepeat(.backspace)
      self.backspaceRepeatCount += deletedCount
      self.scheduleNextBackspaceTick()
    }
  }

  /// 터치 추적 중에도 반복 입력이 멈추지 않도록 메인 런루프의 common mode에 등록한다.
  private func scheduleInputTimer(
    interval: TimeInterval, repeats: Bool, action: @escaping @MainActor () -> Void
  ) -> Timer {
    let documentIdentifier = currentDocumentIdentifier()
    let timer = Timer(timeInterval: interval, repeats: repeats) { [weak self] timer in
      MainActor.assumeIsolated {
        guard let self, self.currentDocumentIdentifier() == documentIdentifier else {
          timer.invalidate()
          return
        }
        action()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    return timer
  }
}

// MARK: - KeyButtonDelegate

extension KeyboardViewController: KeyButtonDelegate {
  func keyButtonTouchesBegan(_ button: KeyButton) {
    guard button.keyValue != KeyboardConstants.KeyID.dummy, !button.keyValue.isEmpty else {
      return
    }
    if button.keyValue == KeyboardConstants.KeyID.space {
      shouldSuppressSpaceTap = false
    }
    KeyboardInputDiagnostics.shared.recordTouch()
    guard let action = keyboardAction(for: button.keyValue), case .character = action else { return }
    if dispatchKeyboardAction(action) {
      button.committedInputGeneration = inputMutationGeneration
    }
  }

  func keyButtonTouchesEnded(_ button: KeyButton, cancelled: Bool) {
    // 안전망: touchesCancelled 등으로 인해 타이머가 정리되지 않은 경우 대비
    let key = button.keyValue

    // 롱프레스 커서 모드가 한 번이라도 활성화된 터치는 띄어쓰기로 처리하지 않는다.
    if key == KeyboardConstants.KeyID.space {
      let shouldInsertSpace = !cancelled && !shouldSuppressSpaceTap
      shouldSuppressSpaceTap = false
      if shouldInsertSpace {
        dispatchKeyboardAction(.space)
      }
    }

    if key == KeyboardConstants.KeyID.backspace {
      stopBackspaceRepeat()
    }
    if key == KeyboardConstants.KeyID.cursorLeft || key == KeyboardConstants.KeyID.cursorRight {
      stopCursorRepeat()
    }
  }
}

// MARK: - CustomKeyboardViewDelegate

extension KeyboardViewController: CustomKeyboardViewDelegate {
  func customKeyboardView(_ view: CustomKeyboardView, didSelectCustom custom: String) {
    KeyboardInputDiagnostics.shared.recordTouch()
    dispatchKeyboardAction(.character(custom))
  }

  func customKeyboardViewDidBeginBackspace(_ view: CustomKeyboardView) {
    KeyboardInputDiagnostics.shared.recordTouch()
    beginBackspaceRepeat()
  }

  func customKeyboardViewDidEndBackspace(_ view: CustomKeyboardView) {
    stopBackspaceRepeat()
  }
}

// MARK: - UIGestureRecognizerDelegate

extension KeyboardViewController: UIGestureRecognizerDelegate {
  // 스페이스바의 롱프레스(커서모드 진입)와 팬(커서 이동)이 동시에 인식되도록 허용.
  // 이게 없으면 롱프레스 인식 후 pan이 막혀 꾹 누른 뒤 드래그해도 커서가 움직이지 않는다.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    return gestureRecognizer.view == spaceButton && otherGestureRecognizer.view == spaceButton
  }
}
