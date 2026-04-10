//
//  KeyboardViewController+Input.swift
//  custom-keyboard
//

import UIKit

extension KeyboardViewController {
  
  // MARK: - 문자 및 한글 입력 로직
  
  @objc func letterTapped(_ sender: KeyButton) {
    let key = sender.keyValue
    guard let ch = key.first else { return }

    if isHangul && ch.isLetter && !isSymbol {
      inputHangul(ch)
    } else {
      flushHangul()
      let toInsert = (ch.isLetter && isShifted && !isSymbol) ? key.uppercased() : key
      textDocumentProxy.insertText(toInsert)
    }

    // 글자 입력 후 일회용 시프트 해제 (심볼 모드가 아닐 때만)
    if isShifted && !isShiftLocked && !isSymbol {
      isShifted = false
      rebuildKeyboard()
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
      textDocumentProxy.insertText(String(ch));
      return;
    }

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

  func flushHangul() {
    guard isHangul else { return; }
    // 이미 insertText로 들어가 있으므로 상태만 초기화
    automata.reset();
    activeLength = 0;
    composingChar = nil;
  }

  // MARK: - 기능 키 핸들링
  
  @objc func shiftTapped() {
    triggerHaptic()
    
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
      triggerHaptic()
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
    triggerHaptic();
    isSymbol.toggle();
    isCustom = false; // 이모지 모드 해제
    // 기호 모드 진입 시 시프트 상태 초기화 (1/2 페이지부터 시작)
    isShifted = false;
    rebuildKeyboard();
  }

  @objc func enterTapped() {
    flushHangul();
    textDocumentProxy.insertText("\n");
  }

  // MARK: - 커서 이동 및 가속
  
  @objc func cursorTouchDown(_ sender: UIButton) {
    guard let id = sender.accessibilityIdentifier else { return }
    // 한 번 클릭 동작 수행
    flushHangul();
    triggerHaptic();
    activeLength = 0;
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
      self.triggerHaptic()
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
    triggerHaptic();
    isCustom.toggle();
    isSymbol = false;
    rebuildKeyboard();
  }

  @objc func dismissTapped() {
    dismissKeyboard()
  }

  @objc func customKeyTapped(_ sender: UIButton) {
    if let custom = sender.accessibilityLabel {
      textDocumentProxy.insertText(custom)
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
    if isHangul && !isSymbol {
      // 한글 조합 중일 때
      // 한글 조합 중일 때 (스택에 자모가 남아있음)
      if !automata.jamoStack.isEmpty {
        // 기존 조합 글자 삭제
        for _ in 0..<activeLength {
          textDocumentProxy.deleteBackward();
        }
        
        automata.backspace();
        triggerHaptic();
        
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
          triggerHaptic();
          textDocumentProxy.deleteBackward();
          activeLength = 0; // 혹시 모를 육안 동기화
        }
      }
    } else {
      // 영문 또는 기호 모드
      if textDocumentProxy.hasText {
        textDocumentProxy.deleteBackward()
        triggerHaptic() // 글자가 지워지므로 진동
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

// MARK: - CustomKeyboardViewDelegate

extension KeyboardViewController: CustomKeyboardViewDelegate {
  func customKeyboardView(_ view: CustomKeyboardView, didSelectCustom custom: String) {
    triggerHaptic()
    textDocumentProxy.insertText(custom)
  }
  
  func customKeyboardViewDidTapBackspace(_ view: CustomKeyboardView) {
    triggerHaptic()
    handleBackspace()
  }
  
  func customKeyboardViewDidRequestHaptic(_ view: CustomKeyboardView) {
    triggerHaptic()
  }
}
