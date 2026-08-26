import UIKit
import os.log

private let logger = OSLog(subsystem: "com.nijoow.keyboard", category: "lifecycle")

@objc(KeyboardViewController)
class KeyboardViewController: UIInputViewController {

  // MARK: - 핵심 상태
  var interactionState = KeyboardInteractionState()
  var isHangul: Bool { interactionState.isHangul }
  var isShifted: Bool { interactionState.isShifted }
  var isShiftLocked: Bool { interactionState.isShiftLocked }
  var isSymbol: Bool { interactionState.isSymbol }
  var isCustom: Bool { interactionState.isEmoji }

  /// 성공한 논리 입력마다 증가한다. 롱 프레스 변형이 자신이 만든 문자를 안전하게
  /// 교체할 수 있는지 판정하고, 다른 손가락 입력을 삭제하지 않게 하는 세대 번호다.
  var inputMutationGeneration: UInt64 = 0
  var popupTargetGeneration: UInt64?

  let automata = HangulAutomata()
  /// 현재 문서에 표시 중인 한글 조합 문자열(밑줄 없는 조합 구현용).
  /// prefix-diff 삭제/삽입의 기준이 된다. flush 시 빈 문자열로 초기화.
  var composedText: String = ""
  var allKeyButtons: [KeyButton] = []
  var shiftButton: KeyButton?
  var spaceButton: KeyButton?
  var nextKeyboardButton: KeyButton?

  // 스페이스바 드래그(커서 이동) 중 다른 키를 덮는 딤 오버레이
  var spaceDragOverlay: SpaceDragOverlayView?

  // MARK: - 레이아웃 캐시 (메모리 최적화)
  var utilityRow: UIView?
  var bottomRow: UIView?
  var mainContentStack: UIStackView?
  var customKeyboardView: CustomKeyboardView?

  // 키보드 전체 높이를 확정하는 제약 (priority 999). 점프 방지의 핵심.
  var keyboardHeightConstraint: NSLayoutConstraint?

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

    func applying(_ height: KeyboardHeightPreset) -> LayoutMetrics {
      LayoutMetrics(
        utilRowH: utilRowH * height.rowScale,
        numberRowH: numberRowH * height.rowScale,
        mainKeyH: mainKeyH * height.rowScale,
        bottomRowH: bottomRowH * height.rowScale,
        cornerRadius: cornerRadius,
        utilCornerRadius: utilCornerRadius,
        keyFontSize: keyFontSize * height.fontScale
      )
    }
  }

  /// 회전 중에는 `viewWillTransition(to:)`가 제공한 폭을 우선 사용한다.
  /// 기기 방향 추정 대신 실제 컨테이너 폭으로 레이아웃을 분류해 iPad 분할 화면도 대응한다.
  var layoutReferenceWidth: CGFloat?
  var isLayoutRefreshScheduled = false

  var currentLayoutWidth: CGFloat {
    if let layoutReferenceWidth, layoutReferenceWidth > 0 { return layoutReferenceWidth }
    if view.bounds.width > 0 { return view.bounds.width }
    if let sceneWidth = view.window?.windowScene?.coordinateSpace.bounds.width, sceneWidth > 0 {
      return sceneWidth
    }
    return deviceIsPad ? 768 : 390
  }

  /// 현재 기기가 아이패드인지
  var deviceIsPad: Bool {
    return traitCollection.userInterfaceIdiom == .pad
  }

  var currentLayoutClass: KeyboardLayoutClass {
    KeyboardLayoutClass.classify(width: currentLayoutWidth, isPad: deviceIsPad)
  }

  @discardableResult
  func updateLayoutReferenceWidth(_ width: CGFloat) -> Bool {
    guard width > 0 else { return false }
    let previous = currentLayoutClass
    layoutReferenceWidth = width
    return previous != currentLayoutClass
  }

  var layoutMetrics: LayoutMetrics {
    let baseMetrics: LayoutMetrics
    switch currentLayoutClass {
    case .widePad:
      baseMetrics = LayoutMetrics(
        utilRowH: 46, numberRowH: 52, mainKeyH: 60, bottomRowH: 54,
        cornerRadius: 16, utilCornerRadius: 13, keyFontSize: 26)
    case .regularPad:
      baseMetrics = LayoutMetrics(
        utilRowH: 42, numberRowH: 46, mainKeyH: 52, bottomRowH: 48,
        cornerRadius: 14, utilCornerRadius: 11, keyFontSize: 24)
    case .widePhone:
      baseMetrics = LayoutMetrics(
        utilRowH: 30, numberRowH: 32, mainKeyH: 34, bottomRowH: 32,
        cornerRadius: 10, utilCornerRadius: 7, keyFontSize: 18)
    case .compactPhone:
      baseMetrics = LayoutMetrics(
        utilRowH: KeyboardConstants.utilityRowHeight,
        numberRowH: KeyboardConstants.numberRowHeight,
        mainKeyH: KeyboardConstants.mainKeyHeight,
        bottomRowH: KeyboardConstants.bottomRowHeight,
        cornerRadius: KeyboardConstants.cornerRadius,
        utilCornerRadius: KeyboardConstants.cornerRadius - 3,
        keyFontSize: KeyboardConstants.keyFontSize)
    }
    return baseMetrics.applying(keyboardSettings.height)
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
  var backspaceHoldStartedAt: TimeInterval?

  // 커서 이동 가속 관련
  var cursorTimer: Timer?
  var cursorStartTimer: Timer?
  var cursorRepeatCount = 0

  // 스페이스바 드래그 커서 이동 관련
  var accumulatedPanX: CGFloat = 0
  var isSpaceCursorModeActive = false
  var shouldSuppressSpaceTap = false

  // 키보드가 직접 문서를 조작하는 동안 동기 selection/text 콜백을 구분하는 중첩 카운터.
  private var documentMutationDepth = 0
  var isPerformingDocumentMutation: Bool { documentMutationDepth > 0 }

  func performDocumentMutation(_ action: () -> Void) {
    documentMutationDepth += 1
    defer { documentMutationDepth = max(0, documentMutationDepth - 1) }
    action()
  }

  // MARK: - 패널 렌더링 상태
  var lastRenderedPanel: KeyboardPanel = .letters

  // MARK: - 사용자 설정
  private(set) var keyboardSettings = KeyboardSettings.default
  private(set) var themePalette = KeyboardThemePalette.make(for: .default)

  // MARK: - 색상 테마 (캐시됨)
  // 매번 새 UIColor를 만드는 대신, 테마 변경 시에만 갱신
  private(set) var keyGlassColor: UIColor = .clear
  private(set) var specialGlassColor: UIColor = .clear
  private(set) var activeGlassColor: UIColor = .clear
  private(set) var activeTextColor: UIColor = .white
  private(set) var keyTextColor: UIColor = .white
  private(set) var specialTextColor: UIColor = .gray

  /// 테마 색상을 현재 다크모드 상태에 맞게 한 번에 갱신
  func refreshThemeColors() {
    themePalette = KeyboardThemePalette.make(for: keyboardSettings)
    keyGlassColor = themePalette.keyBackground
    specialGlassColor = themePalette.specialKeyBackground
    activeGlassColor = themePalette.activeKeyBackground
    keyTextColor = themePalette.keyText
    specialTextColor = themePalette.specialKeyText
    activeTextColor = keyTextColor
    view.backgroundColor = themePalette.keyboardBackground
  }

  /// 앱에서 저장한 설정을 키보드가 나타날 때 한 번만 읽는다.
  /// 입력 중에는 공유 저장소나 색상 파생 로직에 접근하지 않는다.
  @discardableResult
  func reloadKeyboardSettings() -> Bool {
    let previousHeight = keyboardSettings.height
    keyboardSettings = KeyboardPreferencesStore.load()
    KeyboardHaptics.shared.configure(isEnabled: keyboardSettings.hapticsEnabled)
    refreshThemeColors()
    return previousHeight != keyboardSettings.height
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

    reloadKeyboardSettings()
    updateLayoutReferenceWidth(view.bounds.width)

    buildKeyboard()

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
    KeyboardInputDiagnostics.shared.beginSession()
    let heightChanged = reloadKeyboardSettings()
    KeyboardPreferencesStore.recordExtensionActivation(hasFullAccess: hasFullAccess)
    let widthClassChanged = updateLayoutReferenceWidth(view.bounds.width)
    resetKeyboardState()
    if heightChanged || widthClassChanged { buildKeyboard() }
    // 등장 애니메이션 시작 전에 키보드 높이 확정 (점프 방지의 핵심)
    installKeyboardHeightConstraint()
    // 키보드 등장 애니메이션 중 레이아웃 재계산 방지
    UIView.performWithoutAnimation {
      refreshThemeColors()
      updateKeyLabels()
      updateAppearance()
      view.layoutIfNeeded()
    }
    KeyboardHaptics.shared.prepare()
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    nextKeyboardButton?.isHidden = !needsInputModeSwitchKey
  }

  // 기기 회전 대응: 방향이 바뀌면 메트릭이 달라지므로 높이 제약을 갱신하고
  // 레이아웃을 다시 빌드해 행 높이/모서리/폰트를 새 방향에 맞춘다.
  override func viewWillTransition(
    to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    updateLayoutReferenceWidth(size.width)
    coordinator.animate(
      alongsideTransition: { _ in
        self.buildKeyboard()
        self.installKeyboardHeightConstraint()
        UIView.performWithoutAnimation {
          self.updateKeyLabels()
          self.updateAppearance()
          self.view.layoutIfNeeded()
        }
      }, completion: nil)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard updateLayoutReferenceWidth(view.bounds.width), !isLayoutRefreshScheduled else { return }
    isLayoutRefreshScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      defer { self.isLayoutRefreshScheduled = false }
      self.buildKeyboard()
      self.installKeyboardHeightConstraint()
      self.updateKeyLabels()
      self.updateAppearance()
      self.view.layoutIfNeeded()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    os_log("🛑 viewWillDisappear", log: logger, type: .default)
    // 키보드가 닫힐 때 활성화된 타이머 및 무거운 뷰(이모지 패널) 정리
    resetTransientInputState()
    removeCustomPanel()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    os_log("⚠️ didReceiveMemoryWarning", log: logger, type: .error)
    // 메모리 부족 시 이모지 패널 해제 + 이모지 데이터 언로드
    resetTransientInputState()
    removeCustomPanel()
    EmojiProvider.shared.unloadData()
  }

  override func textDidChange(_ textInput: UITextInput?) {
    super.textDidChange(textInput)
    guard !isPerformingDocumentMutation else { return }
    reconcileCompositionWithDocument()
  }

  override func selectionDidChange(_ textInput: UITextInput?) {
    super.selectionDidChange(textInput)
    guard !isPerformingDocumentMutation else { return }
    reconcileCompositionWithDocument()
  }

  // MARK: - Private 헬퍼
  func stopAllTimers() {
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
    cursorStartTimer?.invalidate()
    cursorTimer?.invalidate()
    backspaceStartTimer = nil
    backspaceTimer = nil
    cursorStartTimer = nil
    cursorTimer = nil
  }

  /// 화면 전환·회전·재빌드에 걸쳐 남으면 다음 입력을 막을 수 있는 일시 상태를 한 번에 정리한다.
  func resetTransientInputState() {
    stopAllTimers()
    hidePopup()
    endSpaceDragVisual()
    accumulatedPanX = 0
    isSpaceCursorModeActive = false
    shouldSuppressSpaceTap = false
    popupTargetGeneration = nil
  }

  private func resetKeyboardState() {
    flushHangul()
    interactionState.resetShift()

    if let lastLang = UserDefaults.standard.object(forKey: KeyboardConstants.Storage.hangulMode)
      as? Bool
    {
      interactionState.restoreLanguage(isHangul: lastLang)
    } else {
      interactionState.restoreLanguage(isHangul: true)
    }
  }

  /// 키보드가 일으킨 문서 콜백은 조합을 유지하고, 외부 편집/커서 이동으로 실제 문서가
  /// 달라졌을 때만 조합 상태를 끝낸다. 동기 플래그만으로는 늦게 도착하는 호스트 앱의
  /// 콜백을 구분할 수 없으므로 문서의 현재 접미사와 직접 대조한다.
  private func reconcileCompositionWithDocument() {
    guard !composedText.isEmpty else { return }
    guard let context = textDocumentProxy.documentContextBeforeInput, !context.isEmpty else {
      flushHangul()
      return
    }

    // 일부 호스트 앱은 커서 앞 문맥을 일정 길이로 잘라 제공한다. 조합 문자열이 그보다
    // 길더라도 보이는 범위의 접미사가 같으면 현재 조합이 유지된 것으로 판단한다.
    let visibleComposition = composedText.suffix(context.count)
    guard context.hasSuffix(visibleComposition)
    else {
      flushHangul()
      return
    }
  }

  deinit {
    os_log("🔴 KeyboardViewController DEINIT", log: logger, type: .default)
    stopAllTimers()
  }
}
