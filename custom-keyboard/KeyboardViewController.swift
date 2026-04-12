//
//  KeyboardViewController.swift
//  custom-keyboard
//
//  Created by 이우진 on 4/8/26.
//

import UIKit
import AudioToolbox

@objc(KeyboardViewController)
class KeyboardViewController: UIInputViewController {

  // MARK: - 핵심 상태
  var isHangul: Bool = true
  var isShifted: Bool = false
  var isShiftLocked: Bool = false
  var lastShiftTapTime: Date? // 시프트 더블 탭 판정용
  var isSymbol: Bool = false
  var isCustom: Bool = false
  
  var automata = HangulAutomata();
  var composingChar: Character? = nil;
  var activeLength: Int = 0; // 밑줄 없는 조합을 위한 현재 조합 길이 추적
  var allKeyButtons: [KeyButton] = [];
  var shiftButton: KeyButton?;

  // MARK: - 팝업 상태 (Long Press)
  var popupView: UIView?
  var popupLabels: [UILabel] = []
  var popupItems: [String] = []
  var popupSelectedIndex: Int = -1

  // MARK: - Backspace 타이머
  var backspaceStartTimer: Timer?
  var backspaceTimer: Timer?
  var backspaceRepeatCount = 0
  
  // 커서 이동 가속 관련
  var cursorTimer: Timer?
  var cursorStartTimer: Timer?
  var cursorRepeatCount = 0
  
  // MARK: - 테마 관련 감지
  var wasCustom = false
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

  // MARK: - 색상 테마 (옵시디언 블랙 럭셔리)
  var keyGlassColor: UIColor {
    if isDarkMode {
      // 흑요석처럼 더 깊고 매끄러운 다크 그레이 반투명
      return UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.55);
    } else {
      // 밝고 깨끗한 화이트 글래스 (Frosted Glass)
      return UIColor(white: 1.0, alpha: 0.65);
    }
  }

  var specialGlassColor: UIColor {
    if isDarkMode {
      return UIColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.30);
    } else {
      return UIColor(white: 0.9, alpha: 0.45);
    }
  }

  var activeGlassColor: UIColor {
    if isDarkMode {
      // 다크 모드: 버튼이 빛나는 것처럼 화이트 틴트 강조
      return UIColor(white: 1.0, alpha: 0.9);
    } else {
      // 라이트 모드: 버튼이 눌려진 흑요석처럼 짙게 변함
      return UIColor(white: 0.0, alpha: 0.75);
    }
  }

  var activeTextColor: UIColor {
    // 배경색에 맞춰 텍스트 색상 반전
    return isDarkMode ? .black : .white;
  }

  var keyBorderColor: CGColor {
    if isDarkMode {
      return UIColor(white: 1.0, alpha: 0.22).cgColor;
    } else {
      return UIColor(white: 0.0, alpha: 0.12).cgColor;
    }
  }

  var keyTextColor: UIColor {
    return isDarkMode ? .white : UIColor(white: 0.1, alpha: 1.0);
  }
  
  var specialTextColor: UIColor {
    return isDarkMode ? UIColor(white: 0.75, alpha: 1.0) : UIColor(white: 0.35, alpha: 1.0);
  }

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
      if composingChar != nil || !automata.jamoStack.isEmpty {
        resetKeyboardState();
        rebuildKeyboard();
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

  @available(iOS, introduced: 8.0, deprecated: 17.0, message: "Use trait change registration APIs instead")
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
