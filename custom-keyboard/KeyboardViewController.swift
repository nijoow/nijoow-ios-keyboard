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
  /// 현재 문서에 표시 중인 한글 조합 문자열(밑줄 없는 조합 구현용).
  /// prefix-diff 삭제/삽입의 기준이 된다. flush 시 빈 문자열로 초기화.
  var composedText: String = "";
  var allKeyButtons: [KeyButton] = [];
  var shiftButton: KeyButton?;
  var spaceButton: KeyButton?;

  // 스페이스바 드래그(커서 이동) 중 다른 키를 덮는 딤 오버레이
  var spaceDragOverlay: SpaceDragOverlayView?;

  // MARK: - 레이아웃 캐시 (메모리 최적화)
  var utilityRow: UIView?
  var bottomRow: UIView?
  var mainContentStack: UIStackView?
  var customKeyboardView: CustomKeyboardView?

  // 키보드 전체 높이를 확정하는 제약 (priority 999). 점프 방지의 핵심.
  var keyboardHeightConstraint: NSLayoutConstraint?

  // 라이트모드 배경. 시스템 균일 회색을 덮어 반투명 키가 색감/명암을 머금게 해
  // '바둑돌'이 아닌 유리(클리어 글래스) 느낌을 살린다.
  // backgroundGradient: 베이스 쿨톤 그라데이션, glassBlob1/2: 흐릿한 색 번짐.
  private let backgroundGradient = CAGradientLayer()
  private let glassBlob1 = CAGradientLayer()
  private let glassBlob2 = CAGradientLayer()

  // MARK: - 적응형 레이아웃 메트릭 (기기/방향별)
  //
  // 행 높이·모서리 반경·폰트를 기기(아이폰/아이패드)와 방향(세로/가로)에 맞춰 산출한다.
  // 행 사이의 간격/여백(insetTop 등)은 방향과 무관하게 고정해 desiredKeyboardHeight 식과 일치시킨다.
  struct LayoutMetrics {
    var utilRowH: CGFloat
    var numberRowH: CGFloat
    var mainKeyH: CGFloat
    var bottomRowH: CGFloat
    var cornerRadius: CGFloat
    var utilCornerRadius: CGFloat
    var keyFontSize: CGFloat
  }

  /// 화면이 가로 방향인지 (키보드 익스텐션에서는 UIScreen 기준이 가장 신뢰성 높음)
  var isLandscapeScreen: Bool {
    let s = UIScreen.main.bounds.size
    return s.width > s.height
  }

  /// 현재 기기가 아이패드인지
  var deviceIsPad: Bool {
    return traitCollection.userInterfaceIdiom == .pad
  }

  var layoutMetrics: LayoutMetrics {
    if deviceIsPad {
      // 아이패드: 큰 화면에 맞춰 행 높이·폰트를 키워 키를 충분히 크게
      if isLandscapeScreen {
        return LayoutMetrics(utilRowH: 46, numberRowH: 52, mainKeyH: 60, bottomRowH: 54,
                             cornerRadius: 16, utilCornerRadius: 13, keyFontSize: 26)
      } else {
        return LayoutMetrics(utilRowH: 42, numberRowH: 46, mainKeyH: 52, bottomRowH: 48,
                             cornerRadius: 14, utilCornerRadius: 11, keyFontSize: 24)
      }
    } else if isLandscapeScreen {
      // 아이폰 가로: 세로(기존 고정 높이)와 컴팩트의 중간 정도로
      return LayoutMetrics(utilRowH: 30, numberRowH: 32, mainKeyH: 34, bottomRowH: 32,
                           cornerRadius: 10, utilCornerRadius: 7, keyFontSize: 18)
    } else {
      // 아이폰 세로 (기존 값 유지)
      return LayoutMetrics(utilRowH: KeyboardConstants.UTIL_ROW_H,
                           numberRowH: KeyboardConstants.NUMBER_ROW_H,
                           mainKeyH: KeyboardConstants.MAIN_KEY_H,
                           bottomRowH: KeyboardConstants.BOTTOM_ROW_H,
                           cornerRadius: KeyboardConstants.CORNER_RADIUS,
                           utilCornerRadius: KeyboardConstants.CORNER_RADIUS - 3,
                           keyFontSize: KeyboardConstants.KEY_FONT_SIZE)
    }
  }

  /// 레이아웃 메트릭으로부터 역산한 키보드 전체 높이.
  /// = 상단여백 + 유틸행 + 간격 + (숫자행 + 키행*3 + 행간격*3) + 간격 + 바텀행 + 하단여백
  var desiredKeyboardHeight: CGFloat {
    let m = layoutMetrics
    let insetTop: CGFloat = 6
    let insetBottom: CGFloat = 6
    let utilGap: CGFloat = 7
    let bottomGap: CGFloat = 7
    let rowSpacing: CGFloat = 5
    let contentStack = m.numberRowH + m.mainKeyH * 3 + rowSpacing * 3
    return insetTop + m.utilRowH + utilGap
      + contentStack + bottomGap + m.bottomRowH + insetBottom
  }

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


  // MARK: - 색상 테마 (캐시됨)
  // 매번 새 UIColor를 만드는 대신, 테마 변경 시에만 갱신
  private(set) var keyGlassColor: UIColor = .clear;
  private(set) var specialGlassColor: UIColor = .clear;
  private(set) var activeGlassColor: UIColor = .clear;
  private(set) var activeTextColor: UIColor = .white;
  private(set) var keyTextColor: UIColor = .white;
  private(set) var specialTextColor: UIColor = .gray;

  /// 테마 색상을 현재 다크모드 상태에 맞게 한 번에 갱신
  func refreshThemeColors() {
    let dark = isDarkMode;
    // 클리어 글래스: 라이트모드 키 채움을 크게 낮춰 뒤 배경(색 그라데이션/번짐)이 비치게 한다.
    keyGlassColor = dark
      ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.38)
      : UIColor(white: 1.0, alpha: 0.18);
    specialGlassColor = dark
      ? UIColor(red: 0.01, green: 0.01, blue: 0.01, alpha: 0.18)
      : UIColor(white: 1.0, alpha: 0.10);
    activeGlassColor = dark
      ? UIColor(white: 0.45, alpha: 0.85)
      : UIColor(white: 0.78, alpha: 0.80);
    keyTextColor = dark ? .white : UIColor(white: 0.1, alpha: 1.0);
    specialTextColor = dark ? UIColor(white: 0.75, alpha: 1.0) : UIColor(white: 0.32, alpha: 1.0);
    activeTextColor = keyTextColor;

    // 배경: 다크모드는 시스템 어두운 배경을 그대로 쓰도록 투명.
    // 라이트모드는 옅은 쿨톤 그라데이션 + 흐릿한 색 번짐(블루/핑크)을 깔아
    // 반투명 키가 색감을 머금어 유리처럼 보이게 한다.
    CATransaction.begin();
    CATransaction.setDisableActions(true);
    if dark {
      backgroundGradient.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor];
      glassBlob1.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor];
      glassBlob2.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor];
    } else {
      backgroundGradient.colors = [
        UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1.0).cgColor,
        UIColor(red: 0.82, green: 0.85, blue: 0.90, alpha: 1.0).cgColor
      ];
      glassBlob1.colors = [
        UIColor(red: 0.62, green: 0.78, blue: 0.96, alpha: 0.40).cgColor,
        UIColor(red: 0.62, green: 0.78, blue: 0.96, alpha: 0.0).cgColor
      ];
      glassBlob2.colors = [
        UIColor(red: 0.97, green: 0.78, blue: 0.88, alpha: 0.40).cgColor,
        UIColor(red: 0.97, green: 0.78, blue: 0.88, alpha: 0.0).cgColor
      ];
    }
    CATransaction.commit();
  }

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

    // 배경 레이어들을 가장 뒤(키 아래)에 깐다: 베이스 그라데이션 → 색 번짐 2개 순서
    backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
    backgroundGradient.endPoint = CGPoint(x: 0.5, y: 1.0)
    view.layer.insertSublayer(backgroundGradient, at: 0)

    for blob in [glassBlob1, glassBlob2] {
      blob.type = .radial
      blob.startPoint = CGPoint(x: 0.5, y: 0.5)
      blob.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
    view.layer.insertSublayer(glassBlob1, above: backgroundGradient)
    view.layer.insertSublayer(glassBlob2, above: glassBlob1)

    // 테마 색상 초기화
    refreshThemeColors()

    buildKeyboard()

    if #available(iOS 17.0, *) {
      registerForTraitChanges([UITraitUserInterfaceStyle.self], target: self, action: #selector(themeDidChange))
    }
  }

  @objc private func themeDidChange() {
    refreshThemeColors()
    rebuildKeyboard()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // 배경 레이어들을 뷰 크기에 맞춤 (회전·등장 시 갱신)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    backgroundGradient.frame = view.bounds
    let w = view.bounds.width, h = view.bounds.height
    // 색 번짐: 좌상단(블루), 우하단(핑크)에 부드럽게 퍼지도록 배치
    glassBlob1.frame = CGRect(x: -w * 0.25, y: -h * 0.35, width: w * 0.95, height: h * 1.2)
    glassBlob2.frame = CGRect(x: w * 0.35, y: h * 0.15, width: w * 0.95, height: h * 1.25)
    CATransaction.commit()
  }

  // MARK: - 레이아웃 설정
  //
  // 높이 점프 방지: 키보드 뷰에 확정 높이 제약(desiredKeyboardHeight)을 viewWillAppear에서 건다.
  // 시스템은 등장 애니메이션 시작 시점에 inputView 높이를 읽는데, 그 전(viewDidLoad)에 걸면
  // 시스템이 잠정 높이로 애니메이션을 시작한 뒤 보정하므로 높이가 튄다(896→505→정착).
  // 등장 직전(viewWillAppear)에 걸어야 애니메이션이 처음부터 정확한 높이로 진행된다.
  // 콘텐츠는 view의 top·bottom에 핀 고정되어 이 확정 높이를 행 비율대로 채운다.

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    resetKeyboardState()
    // 등장 애니메이션 시작 전에 키보드 높이 확정 (점프 방지의 핵심)
    installKeyboardHeightConstraint()
    // 키보드 등장 애니메이션 중 레이아웃 재계산 방지
    UIView.performWithoutAnimation {
      refreshThemeColors()
      updateKeyLabels()
      updateAppearance()
      view.layoutIfNeeded()
    }
  }

  // 기기 회전 대응: 방향이 바뀌면 메트릭이 달라지므로 높이 제약을 갱신하고
  // 레이아웃을 다시 빌드해 행 높이/모서리/폰트를 새 방향에 맞춘다.
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: { _ in
      self.buildKeyboard()
      self.installKeyboardHeightConstraint()
      UIView.performWithoutAnimation {
        self.updateKeyLabels()
        self.updateAppearance()
        self.view.layoutIfNeeded()
      }
    }, completion: nil)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    os_log("🛑 viewWillDisappear", log: logger, type: .default)
    // 키보드가 닫힐 때 활성화된 타이머 및 무거운 뷰(이모지 패널) 정리
    stopAllTimers()
    endSpaceDragVisual()
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

    // 키보드가 직접 입력 중인 변경은 무시한다. 우리가 매 키마다 수행하는
    // deleteBackward/insertText도 textDidChange를 유발하므로, 여기서 proxy 컨텍스트를
    // 조회하면 입력 핫패스마다 불필요한 IPC가 누적되어 입력이 씹힌다.
    guard !isSuppressingSelectionChange else { return }

    // 외부적인 변경(터치로 커서 이동 등) 감지 시 한글 조합 상태 종결
    flushHangul()

    // 외부 삭제 감지 (카카오톡 전송 등)
    let before = textDocumentProxy.documentContextBeforeInput ?? ""
    let after = textDocumentProxy.documentContextAfterInput ?? ""
    if before.isEmpty && after.isEmpty {
      if composingChar != nil || !automata.jamoStack.isEmpty {
        resetKeyboardState();
        rebuildKeyboard();
      }
    }
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
    composedText = "";
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
