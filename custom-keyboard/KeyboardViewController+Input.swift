import UIKit

extension KeyboardViewController {

  // MARK: - 문자 및 한글 입력 로직

  // delegate(touchesBegan)로 호출되는 일반 문자 키 전용 입력 함수
  // 특수 키(backspace, cursor, shift 등)는 각자의 addTarget 핸들러에서 처리
  func handleKeyPress(_ sender: KeyButton) {
    let key = sender.keyValue
    if key == KeyboardConstants.KeyID.dummy || key.isEmpty { return }

    // 특수 키는 여기서 처리하지 않음 (addTarget 핸들러에서 담당)
    if KeyboardConstants.KeyID.specialKeys.contains(key)
      || KeyboardConstants.KeyID.cursorKeys.contains(key)
    {
      return
    }

    guard let ch = key.first else { return }
    KeyboardInputDiagnostics.shared.recordInputAction()

    if isHangul && ch.isLetter && !isSymbol {
      inputHangul(ch)
    } else {
      flushHangul()
      performDocumentMutation {
        let toInsert = (ch.isLetter && isShifted && !isSymbol) ? key.uppercased() : key
        insertTextThroughProxy(toInsert)
      }
    }

    // 글자 입력 후 일회용 시프트 해제 (심볼 모드가 아닐 때만)
    if isShifted && !isShiftLocked && !isSymbol {
      isShifted = false
      rebuildKeyboard()
    }
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

    // selectionDidChange 억제: 내부 조작 중 automata 리셋 방지
    performDocumentMutation {
      automata.input(jamo)
      renderComposing()
    }
  }

  /// 조합 중인 한글을 prefix-diff로 문서에 최소 변경 반영한다.
  ///
  /// 기존 구현은 매 키 입력마다 조합 문자열 '전체'를 deleteBackward로 지우고 재삽입했다.
  /// 조합은 띄어쓰기 전까지 누적되므로 단어가 길어질수록 입력 한 번에 필요한 proxy IPC가
  /// O(n)으로 늘어나, 빠르게 칠수록 키가 씹혔다. 여기서는 직전 조합 문자열과의 공통 접두사를
  /// 보존하고 바뀐 꼬리만 지우고 다시 넣어, 입력당 proxy 연산을 O(1)로 만든다.
  /// 반드시 `performDocumentMutation` 안에서 호출해야 한다.
  func renderComposing() {
    let newComposed = automata.compose()
    let common = commonPrefixCount(composedText, newComposed)

    let deleteCount = composedText.count - common
    for _ in 0..<deleteCount {
      deleteBackwardThroughProxy()
    }

    let insertPart = String(newComposed.dropFirst(common))
    if !insertPart.isEmpty {
      insertTextThroughProxy(insertPart)
    }

    composedText = newComposed
  }

  /// 두 문자열이 앞에서부터 공유하는 Character 개수.
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
    // 이미 insertText로 들어가 있으므로 상태만 초기화
    // isHangul guard 제거: 어떤 모드에서든 안전하게 상태를 초기화할 수 있도록 함
    automata.reset()
    composedText = ""
  }

  // MARK: - 기능 키 핸들링

  @objc func shiftTapped() {
    KeyboardInputDiagnostics.shared.recordInputAction()

    if isSymbol {
      // 특수 기호 모드: 단순히 페이지 토글 (1/2 <-> 2/2)
      // 이때는 일회용이 아닌 고정 모드로 동작하도록 함
      isShifted.toggle()
      rebuildKeyboard()
      return
    }

    let now = Date()

    // 1. 고정 모드 해제: 이미 고정되어 있다면 어떤 탭이든 해제
    if isShiftLocked {
      isShiftLocked = false
      isShifted = false
      lastShiftTapTime = nil
      rebuildKeyboard()
      return
    }

    // 2. 더블 탭 판정 (0.3초 이내 다시 클릭)
    if let lastTime = lastShiftTapTime,
      now.timeIntervalSince(lastTime) < KeyboardConstants.Interaction.shiftDoubleTapInterval
    {
      isShiftLocked = true
      isShifted = true
      lastShiftTapTime = nil
    } else {
      // 3. 단일 탭: 일회용 시프트 토글
      isShifted.toggle()
      lastShiftTapTime = now
    }

    rebuildKeyboard()
  }

  @objc func handleShiftLongPress(_ gesture: UILongPressGestureRecognizer) {
    if gesture.state == .began {
      if !isSymbol {
        isShiftLocked = true
        isShifted = true
        rebuildKeyboard()
      }
    }
  }

  @objc func langTapped() {
    KeyboardInputDiagnostics.shared.recordInputAction()
    flushHangul()
    isHangul.toggle()
    isShifted = false
    isShiftLocked = false
    UserDefaults.standard.set(isHangul, forKey: KeyboardConstants.Storage.hangulMode)
    isCustom = false
    isSymbol = false
    rebuildKeyboard()
  }

  @objc func symbolTapped() {
    KeyboardInputDiagnostics.shared.recordInputAction()
    flushHangul()
    isSymbol.toggle()
    isCustom = false  // 이모지 모드 해제
    // 기호 모드 진입 시 시프트 상태 초기화 (1/2 페이지부터 시작)
    isShifted = false
    rebuildKeyboard()
  }

  @objc func enterTapped() {
    KeyboardInputDiagnostics.shared.recordInputAction()
    flushHangul()
    performDocumentMutation {
      insertTextThroughProxy("\n")
    }
  }

  // MARK: - 커서 이동 및 가속

  @objc func cursorTouchDown(_ sender: UIButton) {
    guard let id = sender.accessibilityIdentifier else { return }
    KeyboardInputDiagnostics.shared.recordInputAction()
    // 한 번 클릭 동작 수행
    flushHangul()
    handleCursorMove(id: id)

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

  private func handleCursorMove(id: String) {
    switch id {
    case KeyboardConstants.KeyID.cursorLeft:
      moveCursorThroughProxy(byCharacterOffset: -1)
    case KeyboardConstants.KeyID.cursorRight:
      moveCursorThroughProxy(byCharacterOffset: 1)
    case KeyboardConstants.KeyID.cursorLineStart:
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
    case KeyboardConstants.KeyID.cursorLineEnd:
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
    default: break
    }
  }

  private func startContinuousCursorMove(
    id: String, interval: TimeInterval = KeyboardConstants.Interaction.cursorRepeatInterval
  ) {
    cursorTimer?.invalidate()
    cursorTimer = scheduleInputTimer(interval: interval, repeats: true) { [weak self] in
      guard let self else { return }
      self.handleCursorMove(id: id)
      KeyboardHaptics.shared.playRepeat(.cursor)
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
    KeyboardInputDiagnostics.shared.recordInputAction()
    flushHangul()
    isCustom.toggle()
    isSymbol = false
    rebuildKeyboard()
  }

  @objc func dismissTapped() {
    KeyboardInputDiagnostics.shared.recordInputAction()
    dismissKeyboard()
  }

  @objc func nextKeyboardTapped() {
    KeyboardInputDiagnostics.shared.recordInputAction()
    flushHangul()
    advanceToNextInputMode()
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

      // 한 프레임 안에 임계값 여러 칸을 이동해도 남은 거리를 버리지 않는다.
      while abs(accumulatedPanX) >= threshold {
        let direction = accumulatedPanX > 0 ? 1 : -1
        moveCursorThroughProxy(byCharacterOffset: direction)
        KeyboardHaptics.shared.playRepeat(.cursor)

        // 이동한 만큼의 거리를 뺀 나머지만 남겨서 부드러운 연속 이동 가능케 함
        accumulatedPanX -= CGFloat(direction) * threshold
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
    accumulatedPanX = 0
    shouldSuppressSpaceTap = true
    isSpaceCursorModeActive = true
    beginSpaceDragVisual()
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
    handleBackspace()
    backspaceRepeatCount = 0
    stopBackspaceRepeat()
    backspaceStartTimer = scheduleInputTimer(
      interval: KeyboardConstants.Interaction.backspaceRepeatStartDelay, repeats: false
    ) { [weak self] in
      self?.startContinuousBackspace()
    }
  }

  func stopBackspaceRepeat() {
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
    backspaceStartTimer = nil
    backspaceTimer = nil
  }

  func stopCursorRepeat() {
    cursorStartTimer?.invalidate()
    cursorTimer?.invalidate()
    cursorStartTimer = nil
    cursorTimer = nil
  }

  private func handleBackspace(repeatFeedback: Bool = false) {
    var didDelete = false
    performDocumentMutation {
      if isHangul && !isSymbol {
        // 한글 조합 중일 때 (스택에 자모가 남아있음)
        if !automata.jamoStack.isEmpty {
          // 자모 하나를 제거하고 prefix-diff로 바뀐 부분만 갱신
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
    guard didDelete else { return }
    KeyboardInputDiagnostics.shared.recordInputAction()
    if repeatFeedback { KeyboardHaptics.shared.playRepeat(.backspace) }
  }

  private func startContinuousBackspace(
    interval: TimeInterval = KeyboardConstants.Interaction.repeatInterval
  ) {
    backspaceTimer?.invalidate()
    backspaceTimer = scheduleInputTimer(interval: interval, repeats: true) { [weak self] in
      guard let self else { return }
      self.handleBackspace(repeatFeedback: true)
      self.backspaceRepeatCount += 1

      if self.backspaceRepeatCount == KeyboardConstants.Interaction.fastRepeatThreshold {
        self.startContinuousBackspace(interval: KeyboardConstants.Interaction.fastRepeatInterval)
      } else if self.backspaceRepeatCount
        == KeyboardConstants.Interaction.fastestRepeatThreshold
      {
        self.startContinuousBackspace(
          interval: KeyboardConstants.Interaction.fastestRepeatInterval)
      }
    }
  }

  /// 터치 추적 중에도 반복 입력이 멈추지 않도록 메인 런루프의 common mode에 등록한다.
  private func scheduleInputTimer(
    interval: TimeInterval, repeats: Bool, action: @escaping @MainActor () -> Void
  ) -> Timer {
    let timer = Timer(timeInterval: interval, repeats: repeats) { _ in
      MainActor.assumeIsolated {
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
    KeyboardHaptics.shared.playKeyPress()
    // 일반 문자 키만 delegate에서 즉시 처리 (제로 지연 입력)
    // 특수 키는 addTarget 이벤트(.touchDown/.touchUpInside)로 처리됨
    handleKeyPress(button)
  }

  func keyButtonTouchesEnded(_ button: KeyButton, cancelled: Bool) {
    // 안전망: touchesCancelled 등으로 인해 타이머가 정리되지 않은 경우 대비
    let key = button.keyValue

    // 롱프레스 커서 모드가 한 번이라도 활성화된 터치는 띄어쓰기로 처리하지 않는다.
    if key == KeyboardConstants.KeyID.space {
      let shouldInsertSpace = !cancelled && !shouldSuppressSpaceTap
      shouldSuppressSpaceTap = false
      if shouldInsertSpace {
        flushHangul()
        performDocumentMutation {
          insertTextThroughProxy(KeyboardConstants.KeyID.space)
        }
        KeyboardInputDiagnostics.shared.recordInputAction()
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
    KeyboardInputDiagnostics.shared.recordInputAction()
    KeyboardHaptics.shared.playKeyPress()
    flushHangul()
    performDocumentMutation {
      insertTextThroughProxy(custom)
    }
  }

  func customKeyboardViewDidBeginBackspace(_ view: CustomKeyboardView) {
    KeyboardInputDiagnostics.shared.recordTouch()
    KeyboardHaptics.shared.playKeyPress()
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
