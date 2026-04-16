//
//  KeyboardViewController+Input.swift
//  custom-keyboard
//

import UIKit

extension KeyboardViewController {
  
  // MARK: - 문자 및 한글 입력 로직
  
  @objc func letterTapped(_ sender: KeyButton) {
    // touchesBegan에서 처리하므로 중복 방지를 위해 비워둠 (혹은 무시)
  }

  // delegate(touchesBegan)로 호출되는 일반 문자 키 전용 입력 함수
  // 특수 키(backspace, cursor, shift 등)는 각자의 addTarget 핸들러에서 처리
  func handleKeyPress(_ sender: KeyButton) {
    let key = sender.keyValue;
    if key == "dummy" || key == "" { return; }
    
    // 특수 키는 여기서 처리하지 않음 (addTarget 핸들러에서 담당)
    // 스페이스바(" ")도 탭/드래그 구분을 위해 여기서 제외하고 touchesEnded에서 처리
    let specialKeys = ["shift", "backspace", "lang", "symbol", "enter", "custom", "dismiss", " "];
    if specialKeys.contains(key) || key.contains("cursor") { return; }
    
    // 일반 문자 입력: 즉각 햄틱 + 입력 처리
    
    guard let ch = key.first else { return; }

    if isHangul && ch.isLetter && !isSymbol {
      inputHangul(ch);
    } else {
      flushHangul();
      performWithoutSelectionChange {
        let toInsert = (ch.isLetter && isShifted && !isSymbol) ? key.uppercased() : key;
        textDocumentProxy.insertText(toInsert);
      }
    }

    // 글자 입력 후 일회용 시프트 해제 (심볼 모드가 아닐 때만)
    if isShifted && !isShiftLocked && !isSymbol {
      isShifted = false;
      rebuildKeyboard();
    }
  }

  func inputHangul(_ ch: Character) {
    let jamo: Character;
    if isShifted, let shifted = KeyboardConstants.HANGUL_SHIFT_MAP[ch] {
      jamo = shifted;
    } else if let hangul = KeyboardConstants.HANGUL_MAP[ch] {
      jamo = hangul;
    } else {
      flushHangul();
      performWithoutSelectionChange {
        textDocumentProxy.insertText(String(ch));
      }
      return;
    }

    // selectionDidChange 억제: 내부 조작 중 automata 리셋 방지
    performWithoutSelectionChange {
      // 기존 조합 중인 글자 삭제 (밑줄 없는 효과를 위해)
      for _ in 0..<activeLength {
        textDocumentProxy.deleteBackward();
      }

      automata.input(jamo);
      let combined = automata.compose();
      
      // 새 조합 삽입
      if !combined.isEmpty {
        textDocumentProxy.insertText(combined);
        activeLength = combined.count;
        composingChar = combined.last;
      } else {
        activeLength = 0;
        composingChar = nil;
      }
    }
  }

  func flushHangul() {
    // 이미 insertText로 들어가 있으므로 상태만 초기화
    // isHangul guard 제거: 어떤 모드에서든 안전하게 상태를 초기화할 수 있도록 함
    automata.reset();
    activeLength = 0;
    composingChar = nil;
  }

  // MARK: - 기능 키 핸들링
  
  @objc func shiftTapped() {
    
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
    if let lastTime = lastShiftTapTime, now.timeIntervalSince(lastTime) < 0.3 {
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
    flushHangul()
    isHangul.toggle()
    isShifted = false
    isShiftLocked = false
    UserDefaults.standard.set(isHangul, forKey: "isHangulState")
    automata.reset()
    composingChar = nil
    isCustom = false
    isSymbol = false
    rebuildKeyboard()
  }

  @objc func symbolTapped() {
    flushHangul();
    isSymbol.toggle();
    isCustom = false; // 이모지 모드 해제
    // 기호 모드 진입 시 시프트 상태 초기화 (1/2 페이지부터 시작)
    isShifted = false;
    rebuildKeyboard();
  }

  @objc func enterTapped() {
    flushHangul();
    performWithoutSelectionChange {
      textDocumentProxy.insertText("\n");
    }
  }

  // MARK: - 커서 이동 및 가속
  
  @objc func cursorTouchDown(_ sender: UIButton) {
    guard let id = sender.accessibilityIdentifier else { return }
    // 한 번 클릭 동작 수행
    flushHangul();
    handleCursorMove(id: id);
    
    // 왼쪽/오른쪽 버튼인 경우에만 가속 타이머 작동
    if id == "cursor_left" || id == "cursor_right" {
      cursorRepeatCount = 0
      cursorStartTimer?.invalidate()
      cursorTimer?.invalidate()
      cursorStartTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
        self?.startContinuousCursorMove(id: id)
      }
    }
  }
  
  @objc func cursorTouchUp(_ sender: UIButton) {
    cursorStartTimer?.invalidate()
    cursorTimer?.invalidate()
  }
  
  private func handleCursorMove(id: String) {
    switch id {
    case "cursor_left":
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
    case "cursor_right":
      textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
    case "cursor_line_start":
      let before = textDocumentProxy.documentContextBeforeInput ?? ""
      if before.isEmpty || before.last == "\n" {
        // 이미 줄의 맨 앞이면 이전 줄로 이동
        textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)
      } else {
        // 현재 줄의 맨 앞으로 이동
        if let lastNewline = before.lastIndex(of: "\n") {
          let offset = before.distance(from: lastNewline, to: before.endIndex) - 1
          textDocumentProxy.adjustTextPosition(byCharacterOffset: -offset)
        } else {
          textDocumentProxy.adjustTextPosition(byCharacterOffset: -before.count)
        }
      }
    case "cursor_line_end":
      let after = textDocumentProxy.documentContextAfterInput ?? ""
      if after.isEmpty || after.first == "\n" {
        // 이미 줄의 맨 뒤면 다음 줄로 이동
        textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)
      } else {
        // 현재 줄의 맨 뒤로 이동
        if let firstNewline = after.firstIndex(of: "\n") {
          let offset = after.distance(from: after.startIndex, to: firstNewline)
          textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        } else {
          textDocumentProxy.adjustTextPosition(byCharacterOffset: after.count)
        }
      }
    default: break
    }
  }
  
  private func startContinuousCursorMove(id: String, interval: TimeInterval = 0.1) {
    cursorTimer?.invalidate()
    cursorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.handleCursorMove(id: id)
      self.cursorRepeatCount += 1
      
      if self.cursorRepeatCount == 10 {
        self.startContinuousCursorMove(id: id, interval: 0.05)
      } else if self.cursorRepeatCount == 50 {
        self.startContinuousCursorMove(id: id, interval: 0.03)
      }
    }
  }

  @objc func customTapped() {
    flushHangul();
    isCustom.toggle();
    isSymbol = false;
    rebuildKeyboard();
  }

  @objc func dismissTapped() {
    dismissKeyboard()
  }

  @objc func customKeyTapped(_ sender: UIButton) {
    if let custom = sender.accessibilityLabel {
      flushHangul();
      performWithoutSelectionChange {
        textDocumentProxy.insertText(custom);
      }
    }
  }

  // MARK: - 스페이스바 드래그 커서 이동
  
  @objc func handleSpacePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: gesture.view)
    
    switch gesture.state {
    case .began:
      // 드래그 시작 시 현재 한글 조합을 완료하여 데이터 꼬임 방지
      flushHangul();
      accumulatedPanX = 0;
      isSpaceDragging = true;
      
    case .changed:
      // 이전 실시간 이동량을 누적
      accumulatedPanX += translation.x;
      // 처리가 완료된 상대적 증분만 남기기 위해 translation 리셋
      gesture.setTranslation(.zero, in: gesture.view);
      
      let threshold: CGFloat = 12.0; // 한 칸 이동을 위한 드래그 거리 (픽셀 단위)
      
      if abs(accumulatedPanX) >= threshold {
        let direction = accumulatedPanX > 0 ? 1 : -1;
        textDocumentProxy.adjustTextPosition(byCharacterOffset: direction);
            
        // 이동한 만큼의 거리를 뺀 나머지만 남겨서 부드러운 연속 이동 가능케 함
        accumulatedPanX -= CGFloat(direction) * threshold;
      }
      
    case .ended, .cancelled:
      accumulatedPanX = 0;
      // 약간의 딜레이를 주어 touchesEnded가 먼저 처리될 기회를 주거나 상태를 정리합니다.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        self.isSpaceDragging = false;
      }
      break;
    default:
      break;
    }
  }

  // MARK: - 백스페이스 및 가속 삭제
  
  @objc func backspaceTouchDown(_ sender: UIButton) {
    handleBackspace()
    
    backspaceRepeatCount = 0
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
    backspaceStartTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
      self?.startContinuousBackspace()
    }
  }

  @objc func backspaceTouchUp(_ sender: UIButton) {
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
  }

  private func handleBackspace() {
    performWithoutSelectionChange {
      if isHangul && !isSymbol {
        // 한글 조합 중일 때 (스택에 자모가 남아있음)
        if !automata.jamoStack.isEmpty {
          // 기존 조합 글자 삭제
          for _ in 0..<activeLength {
            textDocumentProxy.deleteBackward();
          }
          
          automata.backspace();
              
          let combined = automata.compose();
          if !combined.isEmpty {
            textDocumentProxy.insertText(combined);
            activeLength = combined.count;
            composingChar = combined.last;
          } else {
            activeLength = 0;
            composingChar = nil;
          }
        } else {
          // 조합 중이 아닐 때 앞 글자(음절) 한 자 삭제
          if textDocumentProxy.hasText {
            textDocumentProxy.deleteBackward();
            activeLength = 0;
          }
        }
      } else {
        // 영문 또는 기호 모드
        if textDocumentProxy.hasText {
          textDocumentProxy.deleteBackward();
        }
      }
    }
  }

  private func startContinuousBackspace(interval: TimeInterval = 0.1) {
    backspaceTimer?.invalidate()
    backspaceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.handleBackspace()
      // handleBackspace 내부에서 햅틱을 처리하므로 여기서 중복 호출하지 않음
      self.backspaceRepeatCount += 1
      
      if self.backspaceRepeatCount == 10 {
        self.startContinuousBackspace(interval: 0.05)
      } else if self.backspaceRepeatCount == 50 {
        self.startContinuousBackspace(interval: 0.03)
      }
    }
  }
}

// MARK: - KeyButtonDelegate

extension KeyboardViewController: KeyButtonDelegate {
  func keyButtonTouchesBegan(_ button: KeyButton) {
    // 일반 문자 키만 delegate에서 즉시 처리 (제로 지연 입력)
    // 특수 키는 addTarget 이벤트(.touchDown/.touchUpInside)로 처리됨
    handleKeyPress(button);
  }
  
  func keyButtonTouchesEnded(_ button: KeyButton) {
    // 안전망: touchesCancelled 등으로 인해 타이머가 정리되지 않은 경우 대비
    let key = button.keyValue;
    
    // 스페이스바 탭 입력 처리 (드래그 중이 아니었을 때만)
    if key == " " && !isSpaceDragging {
      flushHangul();
      performWithoutSelectionChange {
        textDocumentProxy.insertText(" ");
      }
    }
    
    if key == "backspace" {
      backspaceStartTimer?.invalidate();
      backspaceTimer?.invalidate();
    }
    if key == "cursor_left" || key == "cursor_right" {
      cursorStartTimer?.invalidate();
      cursorTimer?.invalidate();
    }
  }
}

// MARK: - CustomKeyboardViewDelegate

extension KeyboardViewController: CustomKeyboardViewDelegate {
  func customKeyboardView(_ view: CustomKeyboardView, didSelectCustom custom: String) {
    flushHangul();
    performWithoutSelectionChange {
      textDocumentProxy.insertText(custom);
    }
  }
  
  func customKeyboardViewDidTapBackspace(_ view: CustomKeyboardView) {
    handleBackspace()
  }}

