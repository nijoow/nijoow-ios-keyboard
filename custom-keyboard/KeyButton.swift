import UIKit

protocol KeyButtonDelegate: AnyObject {
  func keyButtonTouchesBegan(_ button: KeyButton);
  func keyButtonTouchesEnded(_ button: KeyButton);
}

class KeyButton: UIButton {
  weak var touchDelegate: KeyButtonDelegate?;
  var keyValue: String = "";
  var touchAreaInsets: UIEdgeInsets = .zero;
  
  // MARK: - 3D Glass 효과 레이어 (간소화: bezelLayer 제거)
  
  private let glassBodyLayer = CAGradientLayer();
  
  /// 버튼의 기본 배경색 (하이라이트 해제 시 복구용)
  var normalBackgroundColor: UIColor? {
    didSet {
      updateLayerAppearance();
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame);
    setupLayers();
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder);
    setupLayers();
  }
  
  private func setupLayers() {
    // 글래스 바디 그라데이션 (입체감 + 상단 하이라이트 통합)
    glassBodyLayer.locations = [0.0, 0.05, 0.4, 1.0];
    glassBodyLayer.startPoint = CGPoint(x: 0.5, y: 0.0);
    glassBodyLayer.endPoint = CGPoint(x: 0.5, y: 1.0);
    layer.insertSublayer(glassBodyLayer, at: 0);
    
    // masksToBounds = true로 설정하여 그라데이션이 cornerRadius를 따르도록 함
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
    
    // [성능 최적화] shadowPath 명시적 설정으로 GPU 부하 감소
    layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath;
    
    CATransaction.commit();
  }
  
  // [메모리 최적화] 글래스 그라데이션 색상을 static으로 캐시하여 매 호출마다 UIColor 재생성 방지
  private static let darkGlassColors: [CGColor] = [
    UIColor(white: 1.0, alpha: 0.18).cgColor,
    UIColor(white: 1.0, alpha: 0.08).cgColor,
    UIColor(white: 1.0, alpha: 0.0).cgColor,
    UIColor(white: 0.0, alpha: 0.05).cgColor
  ];
  private static let lightGlassColors: [CGColor] = [
    UIColor(white: 1.0, alpha: 0.55).cgColor,
    UIColor(white: 1.0, alpha: 0.35).cgColor,
    UIColor(white: 1.0, alpha: 0.1).cgColor,
    UIColor(white: 0.0, alpha: 0.02).cgColor
  ];

  func updateLayerAppearance() {
    let isDark = traitCollection.userInterfaceStyle == .dark;
    glassBodyLayer.colors = isDark ? KeyButton.darkGlassColors : KeyButton.lightGlassColors;
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
    
    UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
      if self.isHighlighted {
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
