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

    if isShifted && !isShiftLocked {
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
    if isSymbol {
      isShifted.toggle()
      isShiftLocked = false
    } else {
      if !isShifted {
        isShifted = true
        isShiftLocked = false
      } else if !isShiftLocked {
        isShiftLocked = true
      } else {
        isShifted = false
        isShiftLocked = false
      }
    }
    rebuildKeyboard()
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
    flushHangul()
    isSymbol.toggle()
    isShifted = false
    isShiftLocked = false
    isEmoji = false
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
    triggerHaptic()
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
      let result = automata.backspace()
      if composingChar != nil {
        if !result.insert.isEmpty {
          textDocumentProxy.setMarkedText(result.insert, selectedRange: NSRange(location: result.insert.count, length: 0))
          composingChar = result.insert.last
        } else {
          textDocumentProxy.deleteBackward()
          composingChar = nil
        }
      } else {
        for _ in 0..<result.deleteCount {
          textDocumentProxy.deleteBackward()
        }
        if !result.insert.isEmpty {
          textDocumentProxy.setMarkedText(result.insert, selectedRange: NSRange(location: result.insert.count, length: 0))
          composingChar = result.insert.last
        }
      }
    } else {
      textDocumentProxy.deleteBackward()
    }
  }

  private func startContinuousBackspace(interval: TimeInterval = 0.1) {
    backspaceTimer?.invalidate()
    backspaceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      guard let self = self else { return }
      self.handleBackspace()
      self.triggerHaptic()
      self.backspaceRepeatCount += 1
      
      if self.backspaceRepeatCount == 10 {
        self.startContinuousBackspace(interval: 0.05)
      } else if self.backspaceRepeatCount == 50 {
        self.startContinuousBackspace(interval: 0.03)
      }
    }
  }
}
