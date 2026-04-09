//
//  KeyboardViewController.swift
//  njjoow-keyboard
//
//  Created by 이우진 on 4/8/26.
//

import UIKit
import AudioToolbox

class KeyboardViewController: UIInputViewController {

  // MARK: - 핵심 상태
  var isHangul: Bool = true
  var isShifted: Bool = false
  var isShiftLocked: Bool = false
  var isSymbol: Bool = false
  var isEmoji: Bool = false
  
  var automata = HangulAutomata()
  var composingChar: Character? = nil
  var allKeyButtons: [KeyButton] = []
  var shiftButton: KeyButton?

  // MARK: - 팝업 상태 (Long Press)
  var popupView: UIView?
  var popupLabels: [UILabel] = []
  var popupItems: [String] = []
  var popupSelectedIndex: Int = -1

  // MARK: - Backspace 타이머
  var backspaceStartTimer: Timer?
  var backspaceTimer: Timer?
  var backspaceRepeatCount: Int = 0 
  
  // MARK: - 테마 관련 감지
  var wasEmoji = false
  var wasSymbol = false

  var isDarkMode: Bool {
    if textDocumentProxy.keyboardAppearance == .dark { return true }
    if textDocumentProxy.keyboardAppearance == .light { return false }
    return traitCollection.userInterfaceStyle == .dark
  }

  // MARK: - 햅틱 헬퍼
  func triggerHaptic() {
    AudioServicesPlaySystemSound(1519)
  }

  // MARK: - 색상 테마 (글래스모피즘)
  var keyGlassColor: UIColor {
    return isDarkMode ? UIColor(white: 1.0, alpha: 0.14) : UIColor(white: 1.0, alpha: 0.28)
  }

  var specialGlassColor: UIColor {
    return isDarkMode ? UIColor(white: 1.0, alpha: 0.06) : UIColor(white: 0.2, alpha: 0.06)
  }

  var activeGlassColor: UIColor {
    return isDarkMode ? UIColor(white: 1.0, alpha: 0.5) : UIColor(white: 0.5, alpha: 0.3)
  }

  var keyBorderColor: CGColor {
    return isDarkMode ? UIColor(white: 1.0, alpha: 0.12).cgColor : UIColor(white: 0.0, alpha: 0.08).cgColor
  }

  var keyTextColor: UIColor { return isDarkMode ? .white : .black }
  var specialTextColor: UIColor { return isDarkMode ? UIColor(white: 0.85, alpha: 1) : .darkGray }

  // MARK: - Lifecycle
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    resetKeyboardState()
    rebuildKeyboard()
  }

  override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    let before = textDocumentProxy.documentContextBeforeInput ?? ""
    let after = textDocumentProxy.documentContextAfterInput ?? ""
    
    // 외부 삭제 감지 (카카오톡 전송 등)
    if before.isEmpty && after.isEmpty {
      if composingChar != nil || automata.currentChar != nil {
        resetKeyboardState()
        rebuildKeyboard()
      }
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    buildKeyboard()

    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in
        self.rebuildKeyboard()
      }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    rebuildKeyboard()
  }

  @available(iOS, introduced: 8.0, deprecated: 17.0)
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #unavailable(iOS 17.0) {
      if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        rebuildKeyboard()
      }
    }
  }

  override func selectionWillChange(_ textInput: UITextInput?) {
    super.selectionWillChange(textInput)
    flushHangul()
  }

  // MARK: - Private 헬퍼
  private func resetKeyboardState() {
    automata.reset()
    composingChar = nil
    isShifted = false
    isShiftLocked = false
    
    if let lastLang = UserDefaults.standard.object(forKey: "isHangulState") as? Bool {
      isHangul = lastLang
    } else {
      isHangul = true
    }
  }
}
