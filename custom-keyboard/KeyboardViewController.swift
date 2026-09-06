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
  var isApplyingLayoutRefresh = false
  var isLayoutTransitionInProgress = false
  var isKeyboardVisible = false
  var needsLayoutRebuildOnNextAppearance = false

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

  /// 테마 색상을 한 번에 갱신
  func refreshThemeColors() {
    themePalette = KeyboardThemePalette.make(for: keyboardSettings)
    keyGlassColor = themePalette.keyBackground
    specialGlassColor = themePalette.specialKeyBackground
    activeGlassColor = themePalette.activeKeyBackground
    keyTextColor = themePalette.keyText
    specialTextColor = themePalette.specialKeyText
    activeTextColor = keyTextColor
    view.backgroundColor = themePalette.keyboardBackground
    view.isOpaque = false
    inputView?.backgroundColor = themePalette.keyboardBackground
    inputView?.isOpaque = false
  }

  /// 앱에서 저장한 설정을 키보드가 나타날 때 한 번만 읽는다.
  /// 입력 중에는 공유 저장소나 색상 파생 로직에 접근하지 않는다.
  @discardableResult
  func reloadKeyboardSettings() -> Bool {
    let previousHeight = keyboardSettings.height
    keyboardSettings = KeyboardPreferencesStore.load()
    KeyboardHaptics.shared.configure(
      isEnabled: keyboardSettings.hapticsEnabled,
      strength: keyboardSettings.hapticStrength)
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

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(extensionHostDidEnterBackground),
      name: NSNotification.Name.NSExtensionHostDidEnterBackground,
      object: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(extensionHostDidBecomeActive),
      name: NSNotification.Name.NSExtensionHostDidBecomeActive,
      object: nil)

  }

  // MARK: - 레이아웃 설정
  //
  // 높이 점프 방지: 키보드 뷰의 확정 높이는 기존에 검증된 viewWillAppear 시점에 건다.
  // 설정·폭 변경으로 뷰를 다시 만들 때는 높이를 먼저 갱신한 뒤 콘텐츠를 교체해,
  // 한 레이아웃 주기 동안 이전 높이와 새 행 높이가 섞이지 않게 한다.
  // 콘텐츠는 view의 top·bottom에 핀 고정되어 이 확정 높이를 행 비율대로 채운다.

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    isKeyboardVisible = true
    KeyboardInputDiagnostics.shared.beginSession()
    let heightChanged = reloadKeyboardSettings()
    KeyboardPreferencesStore.recordExtensionActivation(hasFullAccess: hasFullAccess)
    let widthClassChanged = updateLayoutReferenceWidth(view.bounds.width)
    resetKeyboardState()
    let shouldRebuild =
      heightChanged || widthClassChanged || needsLayoutRebuildOnNextAppearance
      || !hasKeyboardViewHierarchy
    needsLayoutRebuildOnNextAppearance = false
    UIView.performWithoutAnimation {
      // 새 행 높이로 뷰를 만들기 전에 컨테이너 높이를 먼저 확정한다.
      installKeyboardHeightConstraint()
      if shouldRebuild { buildKeyboard() }
      refreshThemeColors()
      updateKeyLabels()
      updateAppearance()
      view.layoutIfNeeded()
    }
    KeyboardHaptics.shared.prepare()
    os_log(
      "▶️ viewWillAppear fullAccess=%{public}@",
      log: logger,
      type: .default,
      hasFullAccess ? "true" : "false"
    )
  }

  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    nextKeyboardButton?.isHidden = !needsInputModeSwitchKey

    // viewWillAppear 때 아직 확정 폭을 받지 못한 iPad 플로팅/분할 화면은 첫 레이아웃
    // 직전에 보정한다. 다음 run loop로 미루면 한 프레임 동안 잘못된 높이가 보여 점프한다.
    guard !isLayoutTransitionInProgress else { return }
    guard updateLayoutReferenceWidth(view.bounds.width) else { return }
    guard isKeyboardVisible else {
      needsLayoutRebuildOnNextAppearance = true
      return
    }
    guard !isApplyingLayoutRefresh else { return }
    isApplyingLayoutRefresh = true
    defer { isApplyingLayoutRefresh = false }

    UIView.performWithoutAnimation {
      installKeyboardHeightConstraint()
      buildKeyboard()
      updateKeyLabels()
      updateAppearance()
    }
  }

  // 기기 회전 대응: 방향이 바뀌면 메트릭이 달라지므로 높이 제약을 갱신하고
  // 레이아웃을 다시 빌드해 행 높이/모서리/폰트를 새 방향에 맞춘다.
  override func viewWillTransition(
    to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    isLayoutTransitionInProgress = true
    let layoutClassChanged = updateLayoutReferenceWidth(size.width)
    coordinator.animate(
      alongsideTransition: { [weak self] _ in
        guard let self else { return }
        guard layoutClassChanged else { return }
        guard self.isKeyboardVisible else {
          self.needsLayoutRebuildOnNextAppearance = true
          return
        }
        UIView.performWithoutAnimation {
          self.installKeyboardHeightConstraint()
          self.buildKeyboard()
          self.updateKeyLabels()
          self.updateAppearance()
          self.view.layoutIfNeeded()
        }
      },
      completion: { [weak self] _ in
        guard let self else { return }
        self.isLayoutTransitionInProgress = false
        // 드물게 시스템의 최종 컨테이너 폭이 예고한 size와 다르면 다음 레이아웃 전에 보정한다.
        self.view.setNeedsLayout()
      })
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    isKeyboardVisible = false
    os_log("🛑 viewWillDisappear", log: logger, type: .default)
    // 전환 애니메이션 중에는 뷰 계층을 유지하되 입력 타이머와 Taptic 자원은 즉시 멈춘다.
    resetTransientInputState()
    KeyboardHaptics.shared.suspend()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    // iOS는 닫힌 키보드 확장 프로세스를 계속 재사용할 수 있다. 보이지 않는 동안
    // 기본 키의 글래스/그림자 레이어까지 내려 메모리 압박에 의한 종료 가능성을 줄인다.
    releaseKeyboardViewHierarchy()
    EmojiProvider.shared.unloadData()
    os_log("⏹ viewDidDisappear resources released", log: logger, type: .default)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    os_log("⚠️ didReceiveMemoryWarning", log: logger, type: .error)
    // 보이는 동안에는 기본 입력 UI를 보존하고 무거운 선택 패널만 내린다.
    // 이미 내려간 상태라면 전체 키 계층까지 즉시 해제한다.
    resetTransientInputState()
    KeyboardHaptics.shared.suspend()
    if isKeyboardVisible {
      removeCustomPanel()
    } else {
      releaseKeyboardViewHierarchy()
    }
    EmojiProvider.shared.unloadData()
  }

  /// 일부 호스트는 앱 전환 시 키보드 VC의 disappear 콜백보다 확장 호스트 알림을 먼저
  /// 보내거나 VC를 그대로 보존한다. 이 경로에서도 반복 입력과 선택 패널을 정리한다.
  @objc private func extensionHostDidEnterBackground() {
    os_log("🌙 extension host did enter background", log: logger, type: .default)
    KeyboardHaptics.shared.suspend()
    removeCustomPanel()
    EmojiProvider.shared.unloadData()
    // disappear 콜백이 생략되는 호스트에서도 백그라운드 동안 무거운 키 레이어를
    // 유지하지 않는다. `isKeyboardVisible`은 그대로 둬 active 콜백의 복구 판단에 쓴다.
    releaseKeyboardViewHierarchy()
  }

  /// VC가 사라지지 않은 채 호스트만 다시 활성화되는 경로에서는 해제한 계층을 즉시
  /// 복원한다. 일반 재등장 경로는 `viewWillAppear`가 같은 역할을 한다.
  @objc private func extensionHostDidBecomeActive() {
    guard isKeyboardVisible else { return }

    if !hasKeyboardViewHierarchy {
      _ = reloadKeyboardSettings()
      _ = updateLayoutReferenceWidth(view.bounds.width)
      resetKeyboardState()
      needsLayoutRebuildOnNextAppearance = false

      UIView.performWithoutAnimation {
        installKeyboardHeightConstraint()
        buildKeyboard()
        refreshThemeColors()
        updateKeyLabels()
        updateAppearance()
        view.layoutIfNeeded()
      }
      os_log("☀️ extension host active hierarchy restored", log: logger, type: .default)
    }

    KeyboardHaptics.shared.prepare()
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
    endSpaceDragVisual(animated: false)
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
    NotificationCenter.default.removeObserver(self)
    stopAllTimers()
  }
}
