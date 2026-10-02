import UIKit

protocol KeyButtonDelegate: AnyObject {
  func keyButtonTouchesBegan(_ button: KeyButton)
  func keyButtonTouchesEnded(_ button: KeyButton, cancelled: Bool)
}

final class KeyButton: UIButton {
  private static let defaultPalette = KeyboardThemePalette.make(for: .default)

  weak var touchDelegate: KeyButtonDelegate?
  var keyValue = ""
  var committedInputGeneration: UInt64?
  var accessibilityActivationHandler: (() -> Bool)?

  /// 버튼 사이 여백을 이 키로 보정해도 되는지 여부다. 문자·편집 키는 true를 유지하지만,
  /// 키보드 전환·닫기처럼 화면 전체 상태를 바꾸는 키는 실제 버튼 내부 탭만 허용한다.
  var acceptsGapHitRouting = true

  /// 레이아웃 정렬은 기존 키 표면을 기준으로 유지하고 실제 UIButton 프레임만 여백까지 넓힌다.
  private(set) var touchExpansion: UIEdgeInsets = .zero
  override var alignmentRectInsets: UIEdgeInsets { touchExpansion }
  var visualBounds: CGRect { bounds.inset(by: touchExpansion) }
  private let surfaceLayer = CALayer()
  private var surfaceColor: UIColor?

  override var backgroundColor: UIColor? {
    get { surfaceColor }
    set {
      surfaceColor = newValue
      surfaceLayer.backgroundColor = newValue?.cgColor
      super.backgroundColor = .clear
    }
  }

  func expandTouchArea(_ insets: UIEdgeInsets) {
    guard abs(touchExpansion.left - insets.left) > 0.01
      || abs(touchExpansion.right - insets.right) > 0.01
      || abs(touchExpansion.top - insets.top) > 0.01
      || abs(touchExpansion.bottom - insets.bottom) > 0.01 else { return }
    touchExpansion = insets
    invalidateIntrinsicContentSize()
    setNeedsLayout()
    superview?.setNeedsLayout()
  }

  // MARK: - 글래스모피즘 레이어
  // glassBodyLayer: 반투명 바디의 세로 광택(상단 하이라이트 + 하단 음영).
  // rimLayer + rimMaskLayer: 가장자리 림 라이트(상단 밝고 하단 어두운 1px 테두리)로
  //   유리 가장자리를 표현. 원형 곡률 모서리에 정확히 정렬되어 이중 테두리가 생기지 않는다.
  private let glassBodyLayer = CAGradientLayer()
  private let rimLayer = CAGradientLayer()
  private let rimMaskLayer = CAShapeLayer()
  private var isTouchVisuallyActive = false
  private var isVisualReleasePending = false
  private var visualPressStartedAt: TimeInterval = 0
  private var visualReleaseWorkItem: DispatchWorkItem?
  private var glassBodyColors: [CGColor] = KeyButton.defaultPalette.glassBodyColors.map(\.cgColor)
  private var rimColors: [CGColor] = KeyButton.defaultPalette.rimColors.map(\.cgColor)

  /// 버튼의 기본 배경색 (하이라이트 해제 시 복구용)
  var normalBackgroundColor: UIColor? {
    didSet {
      updateLayerAppearance()
    }
  }

  /// 스페이스바 드래그처럼 터치가 끝나거나 취소돼도 눌린 상태를 유지해야 할 때 true.
  var dragActive: Bool = false {
    didSet {
      guard oldValue != dragActive else { return }
      updateHighlightState()
    }
  }

  /// dragActive 상태에서 사용할 강조 배경색 (컨트롤러가 테마 색을 주입)
  var dragActiveColor: UIColor?

  override init(frame: CGRect) {
    super.init(frame: frame)
    setupLayers()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupLayers()
  }

  private func setupLayers() {
    isMultipleTouchEnabled = true
    layer.insertSublayer(surfaceLayer, at: 0)

    // 글래스 바디 그라데이션 (반투명 광택: 상단 림 → 중앙 투명 → 하단 음영)
    glassBodyLayer.locations = [0.0, 0.06, 0.5, 1.0]
    glassBodyLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
    glassBodyLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    glassBodyLayer.masksToBounds = true  // 그라데이션을 둥근 모서리로 정확히 클립
    surfaceLayer.insertSublayer(glassBodyLayer, at: 0)

    // 가장자리 림 라이트: 세로 그라데이션을 '동심 링' 모양으로 마스킹.
    // 바깥 모서리를 버튼과 같은 반경으로 두어야 코너에서 곡률이 어긋나지 않는다.
    rimLayer.locations = [0.0, 0.5, 1.0]
    rimLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
    rimLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    rimMaskLayer.fillColor = UIColor.black.cgColor  // 링 영역만 알파로 통과
    rimMaskLayer.fillRule = .evenOdd
    rimLayer.mask = rimMaskLayer
    surfaceLayer.addSublayer(rimLayer)

    layer.masksToBounds = false

    updateLayerAppearance()
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let visualCenter = CGPoint(x: visualBounds.midX, y: visualBounds.midY)
    titleLabel?.center = visualCenter
    imageView?.center = visualCenter

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    let radius = layer.cornerRadius
    surfaceLayer.frame = visualBounds
    surfaceLayer.cornerRadius = radius
    let surfaceBounds = surfaceLayer.bounds
    glassBodyLayer.frame = surfaceBounds
    glassBodyLayer.cornerRadius = radius

    // 림 라이트(테두리) 경로 갱신 — 동심 링(바깥 반경 = 버튼 반경, 안쪽 = 반경 - 두께)
    rimLayer.frame = surfaceBounds
    rimMaskLayer.frame = surfaceBounds
    let ringWidth: CGFloat = 1.0
    let ringPath = UIBezierPath(roundedRect: surfaceBounds, cornerRadius: radius)
    ringPath.append(
      UIBezierPath(
        roundedRect: surfaceBounds.insetBy(dx: ringWidth, dy: ringWidth),
        cornerRadius: max(radius - ringWidth, 0)
      ))
    ringPath.usesEvenOddFillRule = true
    rimMaskLayer.path = ringPath.cgPath

    // [성능 최적화] shadowPath 명시적 설정으로 GPU 부하 감소
    layer.shadowPath = UIBezierPath(roundedRect: visualBounds, cornerRadius: radius).cgPath

    CATransaction.commit()
  }

  func applyGlassPalette(_ palette: KeyboardThemePalette) {
    glassBodyColors = palette.glassBodyColors.map(\.cgColor)
    rimColors = palette.rimColors.map(\.cgColor)
    updateLayerAppearance()
  }

  func updateLayerAppearance() {
    glassBodyLayer.colors = glassBodyColors
    rimLayer.colors = rimColors
    backgroundColor = normalBackgroundColor
  }

  // MARK: - 터치 이벤트

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // 새 터치의 대상 선택은 실제 버튼 사각형으로 제한한다. 이전 키를 떼기 전에 다음 키를
    // 누르는 빠른 입력에서도 기존 키의 추적 여유 영역이 새 터치를 가로채지 않는다.
    guard bounds.contains(point) else { return nil }
    return super.hitTest(point, with: event)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // 행 컨테이너가 여백 터치를 이 버튼으로 선택한 뒤에는 손가락이 조금 움직여도
    // touchUpInside와 스페이스바 탭이 취소되지 않도록 추적 판정만 넉넉히 유지한다.
    bounds.insetBy(
      dx: -KeyboardConstants.Interaction.keyTrackingHitSlop,
      dy: -KeyboardConstants.Interaction.keyTrackingHitSlop
    ).contains(point)
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    beginTouchVisual()
    super.touchesBegan(touches, with: event)
    touchDelegate?.keyButtonTouchesBegan(self)
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    let endedInside = touches.contains { touch in
      self.point(inside: touch.location(in: self), with: event)
    }
    super.touchesEnded(touches, with: event)
    endTouchVisual()
    touchDelegate?.keyButtonTouchesEnded(self, cancelled: !endedInside)
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    endTouchVisual()
    touchDelegate?.keyButtonTouchesEnded(self, cancelled: true)
  }

  override func accessibilityActivate() -> Bool {
    accessibilityActivationHandler?() ?? super.accessibilityActivate()
  }

  // MARK: - 터치 피드백 (하이라이트 효과)

  override var isHighlighted: Bool {
    didSet {
      guard oldValue != isHighlighted else { return }
      // UIKit의 tracking 상태는 보조 신호로만 사용한다. 여백에서 보정 전달된 터치는
      // 별도의 touch visual 상태가 눌림 효과를 책임진다.
      if !isTouchVisuallyActive && !isVisualReleasePending {
        updateHighlightState(animated: true)
      }
    }
  }

  private func beginTouchVisual() {
    visualReleaseWorkItem?.cancel()
    visualReleaseWorkItem = nil
    isVisualReleasePending = false
    isTouchVisuallyActive = true
    visualPressStartedAt = ProcessInfo.processInfo.systemUptime
    updateHighlightState(animated: false)
  }

  private func endTouchVisual() {
    isTouchVisuallyActive = false
    isVisualReleasePending = true

    let elapsed = ProcessInfo.processInfo.systemUptime - visualPressStartedAt
    let delay = max(0, KeyboardConstants.Interaction.minimumPressVisualDuration - elapsed)
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, !self.isTouchVisuallyActive else { return }
      self.isVisualReleasePending = false
      self.visualReleaseWorkItem = nil
      self.updateHighlightState(animated: true)
    }
    visualReleaseWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func updateHighlightState(animated: Bool = true) {
    let changes = {
      if self.dragActive {
        // 드래그 중: 또렷하게 살짝 눌린 강조 상태를 유지 (터치가 취소돼도 풀리지 않음)
        self.glassBodyLayer.opacity = 1.0
        self.rimLayer.opacity = 1.0
        self.alpha = 1.0
        self.backgroundColor = self.dragActiveColor ?? self.normalBackgroundColor
      } else if self.isTouchVisuallyActive || self.isVisualReleasePending || self.isHighlighted {
        // UIView 자체의 transform은 hit-test 영역까지 줄이므로 사용하지 않는다.
        // 표면/림의 투명도만 바꿔 터치 영역은 고정한 채 눌림을 표현한다.
        self.glassBodyLayer.opacity = 0.45
        self.rimLayer.opacity = 0.65
        self.alpha = 0.78
      } else {
        self.glassBodyLayer.opacity = 1.0
        self.rimLayer.opacity = 1.0
        self.alpha = 1.0
        self.backgroundColor = self.normalBackgroundColor
      }
    }

    if animated {
      UIView.animate(
        withDuration: 0.09,
        delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction],
        animations: changes
      )
    } else {
      // 짧은 탭에서도 첫 프레임부터 확실히 보이도록 진행 중인 해제 애니메이션을 끊는다.
      layer.removeAllAnimations()
      glassBodyLayer.removeAllAnimations()
      rimLayer.removeAllAnimations()
      UIView.performWithoutAnimation(changes)
    }
  }
}
