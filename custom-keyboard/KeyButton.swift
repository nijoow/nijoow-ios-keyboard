import UIKit

protocol KeyButtonDelegate: AnyObject {
  func keyButtonTouchesBegan(_ button: KeyButton);
  func keyButtonTouchesEnded(_ button: KeyButton);
}

class KeyButton: UIButton {
  weak var touchDelegate: KeyButtonDelegate?;
  var keyValue: String = "";
  var touchAreaInsets: UIEdgeInsets = .zero;
  
  // MARK: - 글래스모피즘 레이어
  // glassBodyLayer: 반투명 바디의 세로 광택(상단 하이라이트 + 하단 음영).
  // rimLayer + rimMaskLayer: 가장자리 림 라이트(상단 밝고 하단 어두운 1px 테두리)로
  //   유리 가장자리를 표현. 원형 곡률 모서리에 정확히 정렬되어 이중 테두리가 생기지 않는다.
  private let glassBodyLayer = CAGradientLayer();
  private let rimLayer = CAGradientLayer();
  private let rimMaskLayer = CAShapeLayer();
  
  /// 버튼의 기본 배경색 (하이라이트 해제 시 복구용)
  var normalBackgroundColor: UIColor? {
    didSet {
      updateLayerAppearance();
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
    super.init(frame: frame);
    setupLayers();
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder);
    setupLayers();
  }
  
  private func setupLayers() {
    // 글래스 바디 그라데이션 (반투명 광택: 상단 림 → 중앙 투명 → 하단 음영)
    glassBodyLayer.locations = [0.0, 0.06, 0.5, 1.0];
    glassBodyLayer.startPoint = CGPoint(x: 0.5, y: 0.0);
    glassBodyLayer.endPoint = CGPoint(x: 0.5, y: 1.0);
    glassBodyLayer.masksToBounds = true;   // 그라데이션을 둥근 모서리로 정확히 클립
    layer.insertSublayer(glassBodyLayer, at: 0);

    // 가장자리 림 라이트: 세로 그라데이션을 '동심 링' 모양으로 마스킹.
    // 바깥 모서리를 버튼과 같은 반경으로 두어야 코너에서 곡률이 어긋나지 않는다.
    rimLayer.locations = [0.0, 0.5, 1.0];
    rimLayer.startPoint = CGPoint(x: 0.5, y: 0.0);
    rimLayer.endPoint = CGPoint(x: 0.5, y: 1.0);
    rimMaskLayer.fillColor = UIColor.black.cgColor;   // 링 영역만 알파로 통과
    rimMaskLayer.fillRule = .evenOdd;
    rimLayer.mask = rimMaskLayer;
    layer.addSublayer(rimLayer);

    layer.masksToBounds = false;

    updateLayerAppearance();
  }

  override func layoutSubviews() {
    super.layoutSubviews();

    CATransaction.begin();
    CATransaction.setDisableActions(true);

    let radius = layer.cornerRadius;
    glassBodyLayer.frame = bounds;
    glassBodyLayer.cornerRadius = radius;

    // 림 라이트(테두리) 경로 갱신 — 동심 링(바깥 반경 = 버튼 반경, 안쪽 = 반경 - 두께)
    rimLayer.frame = bounds;
    rimMaskLayer.frame = bounds;
    let ringWidth: CGFloat = 1.0;
    let ringPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius);
    ringPath.append(UIBezierPath(
      roundedRect: bounds.insetBy(dx: ringWidth, dy: ringWidth),
      cornerRadius: max(radius - ringWidth, 0)
    ));
    ringPath.usesEvenOddFillRule = true;
    rimMaskLayer.path = ringPath.cgPath;

    // [성능 최적화] shadowPath 명시적 설정으로 GPU 부하 감소
    layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath;

    CATransaction.commit();
  }

  // [메모리 최적화] 글래스 그라데이션 색상을 static으로 캐시하여 매 호출마다 UIColor 재생성 방지
  private static let darkGlassColors: [CGColor] = [
    UIColor(white: 1.0, alpha: 0.22).cgColor,
    UIColor(white: 1.0, alpha: 0.09).cgColor,
    UIColor(white: 1.0, alpha: 0.0).cgColor,
    UIColor(white: 0.0, alpha: 0.07).cgColor
  ];
  // 프로스트 글래스: 상단에만 옅은 광택을 남겨 도밍 없이 평평한 유리 표면을 만든다.
  // (틴트/존재감은 keyGlassColor 채움이 담당)
  private static let lightGlassColors: [CGColor] = [
    UIColor(white: 1.0, alpha: 0.28).cgColor,
    UIColor(white: 1.0, alpha: 0.06).cgColor,
    UIColor(white: 1.0, alpha: 0.0).cgColor,
    UIColor(white: 1.0, alpha: 0.0).cgColor
  ];

  // 테두리 림 라이트(상단 밝음 → 하단 어두움)
  private static let darkRimColors: [CGColor] = [
    UIColor(white: 1.0, alpha: 0.5).cgColor,
    UIColor(white: 1.0, alpha: 0.12).cgColor,
    UIColor(white: 0.0, alpha: 0.22).cgColor
  ];
  // 라이트모드 베벨: 밝은 배경에서 키가 묻히지 않도록 상단은 밝게, 하단 엣지는
  // 약간의 어두움으로 또렷이 분리한다.
  private static let lightRimColors: [CGColor] = [
    UIColor(white: 1.0, alpha: 0.92).cgColor,
    UIColor(white: 1.0, alpha: 0.30).cgColor,
    UIColor(white: 0.0, alpha: 0.13).cgColor
  ];

  func updateLayerAppearance() {
    let isDark = traitCollection.userInterfaceStyle == .dark;
    glassBodyLayer.colors = isDark ? KeyButton.darkGlassColors : KeyButton.lightGlassColors;
    rimLayer.colors = isDark ? KeyButton.darkRimColors : KeyButton.lightRimColors;
    backgroundColor = normalBackgroundColor;
  }
  
  // MARK: - 터치 이벤트 최적화
  // super를 호출하여 UIControl 이벤트(.touchDown 등)를 정상 전달하면서
  // delegate도 함께 호출하여 일반 글자 키의 제로 지연 입력을 유지
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event);
    isHighlighted = true;
    touchDelegate?.keyButtonTouchesBegan(self);
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event);
    isHighlighted = false;
    touchDelegate?.keyButtonTouchesEnded(self);
  }
  
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event);
    isHighlighted = false;
    touchDelegate?.keyButtonTouchesEnded(self);
  }
  
  // MARK: - 히트 테스트 영역 최적화
  
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let area = bounds.inset(by: touchAreaInsets);
    return area.contains(point);
  }
  
  // MARK: - 터치 피드백 (하이라이트 효과)
  
  override var isHighlighted: Bool {
    didSet {
      guard oldValue != isHighlighted else { return }
      updateHighlightState()
    }
  }
  
  private func updateHighlightState() {
    let isDark = traitCollection.userInterfaceStyle == .dark;

    UIView.animate(withDuration: 0.12, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
      if self.dragActive {
        // 드래그 중: 또렷하게 살짝 눌린 강조 상태를 유지 (터치가 취소돼도 풀리지 않음)
        self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97);
        self.glassBodyLayer.opacity = 1.0;
        self.alpha = 1.0;
        self.backgroundColor = self.dragActiveColor ?? self.normalBackgroundColor;
      } else if self.isHighlighted {
        self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92);
        self.glassBodyLayer.opacity = 0.5;
        if isDark { self.alpha = 0.7; }
        else { self.backgroundColor = UIColor(white: 0.0, alpha: 0.15); }
      } else {
        self.transform = .identity;
        self.glassBodyLayer.opacity = 1.0;
        self.alpha = 1.0;
        self.backgroundColor = self.normalBackgroundColor;
      }
    }, completion: nil);
  }
}
