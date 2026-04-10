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
    // 흑요석처럼 깊은 검정빛 반투명 (Smoky Black Glass)
    return UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.45)
  }

  var specialGlassColor: UIColor {
    // 특수 키는 더 투명하고 깊은 느낌으로 처리
    return UIColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.30)
  }

  var activeGlassColor: UIColor {
    // 활성화 상태(시프트 등)는 내부에서 빛이 은은하게 감도는 화이트 틴트
    return UIColor(white: 0.6, alpha: 0.30)
  }

  var keyBorderColor: CGColor {
    // 실버 에지(Edge) 느낌을 주는 정교한 화이트 오파시티 테두리
    return UIColor(white: 1.0, alpha: 0.18).cgColor
  }

  var keyTextColor: UIColor { return .white } // 명확한 화이트 텍스트
  var specialTextColor: UIColor { return UIColor(white: 0.75, alpha: 1.0) } // 고급스런 실버/그레이 톤

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
