//
//  KeyboardViewController.swift
//  custom-keyboard
//
//  Created by 이우진 on 4/8/26.
//

import UIKit
import AudioToolbox
import os.log

let logger = OSLog(subsystem: "com.nijoow.keyboard", category: "lifecycle")

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

  // MARK: - 레이아웃 캐시 (메모리 최적화)
  var utilityRow: UIView?
  var bottomRow: UIView?
  var mainContentStack: UIStackView?
  var customKeyboardView: CustomKeyboardView?
  var heightConstraint: NSLayoutConstraint?

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
  
  // 스페이스바 드래그 커서 이동 관련
  var accumulatedPanX: CGFloat = 0;
  var isSpaceDragging: Bool = false;
  
  // 키보드가 직접 텍스트를 조작 중일 때 selectionDidChange 리셋을 방지하는 카운터
  private var suppressionCount = 0;
  var isSuppressingSelectionChange: Bool {
    return suppressionCount > 0
  }
  
  func startSuppressingSelectionChange() {
    suppressionCount += 1
  }
  
  func stopSuppressingSelectionChange() {
    suppressionCount = max(0, suppressionCount - 1)
  }

  func performWithoutSelectionChange(_ action: () -> Void) {
    startSuppressingSelectionChange()
    defer { stopSuppressingSelectionChange() }
    action()
  }
  
  // MARK: - 테마 관련 감지
  var wasCustom = false
  var wasSymbol = false

  var isDarkMode: Bool {
    if textDocumentProxy.keyboardAppearance == .dark { return true }
    if textDocumentProxy.keyboardAppearance == .light { return false }
    return traitCollection.userInterfaceStyle == .dark
  }


  // MARK: - 색상 테마 (캐시됨 — computed property 제거로 UIColor 재생성 방지)
  // 매번 새 UIColor를 만드는 대신, 테마 변경 시에만 갱신
  private(set) var keyGlassColor: UIColor = .clear;
  private(set) var specialGlassColor: UIColor = .clear;
  private(set) var activeGlassColor: UIColor = .clear;
  private(set) var activeTextColor: UIColor = .white;
  private(set) var keyBorderColor: CGColor = UIColor.clear.cgColor;
  private(set) var keyTextColor: UIColor = .white;
  private(set) var specialTextColor: UIColor = .gray;

  /// 테마 색상을 현재 다크모드 상태에 맞게 한 번에 갱신
  func refreshThemeColors() {
    let dark = isDarkMode;
    keyGlassColor = dark
      ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.55)
      : UIColor(white: 1.0, alpha: 0.65);
    specialGlassColor = dark
      ? UIColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.30)
      : UIColor(white: 0.9, alpha: 0.45);
    activeGlassColor = dark
      ? UIColor(white: 0.45, alpha: 0.85)
      : UIColor(white: 0.75, alpha: 0.85);
    keyTextColor = dark ? .white : UIColor(white: 0.1, alpha: 1.0);
    specialTextColor = dark ? UIColor(white: 0.75, alpha: 1.0) : UIColor(white: 0.35, alpha: 1.0);
    activeTextColor = keyTextColor;
    keyBorderColor = dark
      ? UIColor(white: 1.0, alpha: 0.22).cgColor
      : UIColor(white: 0.0, alpha: 0.12).cgColor;
  }

  // MARK: - Lifecycle
  // MARK: - Lifecycle

  override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    os_log("🟢 KeyboardViewController INIT", log: logger, type: .default)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    os_log("🟢 KeyboardViewController INIT(coder)", log: logger, type: .default)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    // 테마 색상 초기화 (이후 computed property 접근 대신 캐시된 값 사용)
    refreshThemeColors()
    
    // 시스템에 키보드 높이를 명시적으로 알려주어 레이아웃 점프 방지
    // Safe Area 패딩은 시스템이 이 높이 바깥에 자동으로 추가함
    let hc = view.heightAnchor.constraint(equalToConstant: KeyboardConstants.TOTAL_CONTENT_H)
    hc.priority = UILayoutPriority(999)
    hc.isActive = true
    heightConstraint = hc
    
    buildKeyboard()

    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self], target: self, action: #selector(themeDidChange))
    }
  }
  
  @objc private func themeDidChange() {
    refreshThemeColors()
    rebuildKeyboard()
  }

  // MARK: - 레이아웃 점프 방지
  // 시스템의 키보드 등장 애니메이션 중 내부 제약 조건 해석으로 인한
  // 암묵적 레이어 애니메이션을 완전히 차단합니다.
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    os_log("📐 viewWillLayoutSubviews - height: %f", log: logger, type: .default, self.view.frame.height)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    os_log("📐 viewDidLayoutSubviews - height: %f", log: logger, type: .default, self.view.frame.height)
    CATransaction.commit()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    os_log("🚀 viewWillAppear", log: logger, type: .default)
    resetKeyboardState()
    // 키보드 등장 애니메이션 중 레이아웃 재계산 방지
    UIView.performWithoutAnimation {
      refreshThemeColors()
      updateKeyLabels()
      updateAppearance()
      view.layoutIfNeeded()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    os_log("🛑 viewWillDisappear", log: logger, type: .default)
    // 키보드가 닫힐 때 활성화된 타이머 및 무거운 뷰(이모지 패널) 정리
    stopAllTimers()
    if customKeyboardView != nil {
      customKeyboardView?.removeFromSuperview()
      customKeyboardView = nil
      isCustom = false
    }
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // 메모리 부족 시 이모지 패널 해제 + 이모지 데이터 언로드
    if customKeyboardView != nil {
      customKeyboardView?.removeFromSuperview()
      customKeyboardView = nil
      isCustom = false
      rebuildKeyboard()
    }
    EmojiProvider.shared.unloadData()
  }

  override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    
    // 외부적인 변경(터치로 커서 이동 등) 감지 시 한글 조합 상태 종결
    if !isSuppressingSelectionChange {
      flushHangul()
    }
    
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

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated);
    // viewDidAppear에서 추가 rebuildKeyboard 호출 불필요 (viewWillAppear에서 처리됨)
  }

  override func selectionWillChange(_ textInput: UITextInput?) {
    super.selectionWillChange(textInput);

    // 외부적인 선택 변경(사용자 터치 등)이 발생하면 현재 한글 조합 상태를 즉시 종결
    guard !isSuppressingSelectionChange else { return; }
    flushHangul();
  }

  override func selectionDidChange(_ textInput: UITextInput?) {
    super.selectionDidChange(textInput);

    // 키보드가 직접 조작 중인 경우가 아니면 한글 조합 상태 초기화
    guard !isSuppressingSelectionChange else { return; }
    flushHangul();
  }

  @available(iOS, introduced: 8.0, deprecated: 17.0, message: "Use trait change registration APIs instead")
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #unavailable(iOS 17.0) {
      if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
        refreshThemeColors()
        rebuildKeyboard()
      }
    }
  }



  // MARK: - Private 헬퍼
  private func stopAllTimers() {
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
    cursorStartTimer?.invalidate()
    cursorTimer?.invalidate()
  }

  private func resetKeyboardState() {
    automata.reset();
    composingChar = nil;
    activeLength = 0;
    isShifted = false;
    isShiftLocked = false;
    
    if let lastLang = UserDefaults.standard.object(forKey: "isHangulState") as? Bool {
      isHangul = lastLang
    } else {
      isHangul = true
    }
  }

  deinit {
    os_log("🔴 KeyboardViewController DEINIT", log: logger, type: .default)
    stopAllTimers()
    
    // [메모리 최적화] OS가 뷰의 백킹스토어를 캐싱하는 것을 방지하기 위해 계층 구조 파괴
    view.subviews.forEach { $0.removeFromSuperview() }
    allKeyButtons.removeAll()
  }
}
