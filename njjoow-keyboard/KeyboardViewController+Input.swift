//
//  KeyboardViewController+Input.swift
//  njjoow-keyboard
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
    let jamo: Character
    if isShifted, let shifted = KeyboardConstants.HANGUL_SHIFT_MAP[ch] {
      jamo = shifted
    } else if let hangul = KeyboardConstants.HANGUL_MAP[ch] {
      jamo = hangul
    } else {
      flushHangul()
      textDocumentProxy.insertText(String(ch))
      return
    }

    let result = automata.input(jamo)
    if !result.commit.isEmpty {
      textDocumentProxy.insertText(result.commit)
    }

    if let current = result.current {
      textDocumentProxy.setMarkedText(String(current), selectedRange: NSRange(location: 1, length: 0))
      composingChar = current
    } else {
      textDocumentProxy.unmarkText()
      composingChar = nil
    }
  }

  func flushHangul() {
    guard isHangul else { return }
    let committed = automata.flush()
    if !committed.isEmpty {
      textDocumentProxy.insertText(committed)
    } else {
      textDocumentProxy.unmarkText()
    }
    composingChar = nil
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
    isEmoji = false
    isSymbol = false
    rebuildKeyboard()
  }

  @objc func symbolTapped() {
    triggerHaptic()
    isSymbol.toggle()
    // 기호 모드 진입 시 시프트 상태 초기화 (1/2 페이지부터 시작)
    isShifted = false
    rebuildKeyboard()
  }

  @objc func enterTapped() {
    flushHangul()
    textDocumentProxy.insertText("\n")
  }

  @objc func emojiTapped() {
    flushHangul()
    isEmoji.toggle()
    isSymbol = false
    rebuildKeyboard()
  }

  @objc func dismissTapped() {
    dismissKeyboard()
  }

  @objc func emojiKeyTapped(_ sender: UIButton) {
    if let emoji = sender.accessibilityLabel {
      textDocumentProxy.insertText(emoji)
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
      if composingChar != nil {
        let result = automata.backspace()
        triggerHaptic() // 조합 중인 획이 지워지므로 진동
        
        if !result.insert.isEmpty {
          textDocumentProxy.setMarkedText(result.insert, selectedRange: NSRange(location: result.insert.count, length: 0))
          composingChar = result.insert.last
        } else {
          textDocumentProxy.deleteBackward()
          composingChar = nil
        }
      } else {
        // 조합 중이 아닐 때 앞 글자 삭제 시도
        if textDocumentProxy.hasText {
          _ = automata.backspace()
          triggerHaptic() // 글자가 지워지므로 진동
          textDocumentProxy.deleteBackward()
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
