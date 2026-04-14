//
//  KeyButton.swift
//  custom-keyboard
//

import UIKit

protocol KeyButtonDelegate: AnyObject {
  func keyButtonTouchesBegan(_ button: KeyButton);
  func keyButtonTouchesEnded(_ button: KeyButton);
}

class KeyButton: UIButton {
  weak var touchDelegate: KeyButtonDelegate?;
  var keyValue: String = "";
  var touchAreaInsets: UIEdgeInsets = .zero;
  
  // MARK: - 3D Glass 효과 레이어
  
  private let glassBodyLayer = CAGradientLayer();
  private let bezelLayer = CALayer(); // 상단 반사광 엣지
  
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
    // 1. 글래스 바디 그라데이션 (입체감)
    glassBodyLayer.locations = [0.0, 0.4, 1.0];
    glassBodyLayer.startPoint = CGPoint(x: 0.5, y: 0.0);
    glassBodyLayer.endPoint = CGPoint(x: 0.5, y: 1.0);
    layer.insertSublayer(glassBodyLayer, at: 0);
    
    // 2. 상단 베젤 하이라이트 (유리 엣지 반사)
    layer.addSublayer(bezelLayer);
    
    // 기본 레이어 설정
    layer.masksToBounds = true;
    
    // [성능 최적화] 정지 상태의 레이어를 비트맵으로 캐싱하여 렌더링 부하 감소
    layer.shouldRasterize = true;
    layer.rasterizationScale = traitCollection.displayScale;
    
    updateLayerAppearance();
  }
  
  override func layoutSubviews() {
    super.layoutSubviews();
    
    CATransaction.begin();
    CATransaction.setDisableActions(true);
    
    let radius = layer.cornerRadius;
    glassBodyLayer.frame = bounds;
    glassBodyLayer.cornerRadius = radius;
    
    bezelLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.8);
    bezelLayer.cornerRadius = radius;
    
    // [성능 최적화] shadowPath 및 rasterizationScale 업데이트
    layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath;
    layer.rasterizationScale = traitCollection.displayScale;
    
    CATransaction.commit();
  }
  
  func updateLayerAppearance() {
    let isDark = traitCollection.userInterfaceStyle == .dark;
    
    if isDark {
      glassBodyLayer.colors = [
        UIColor(white: 1.0, alpha: 0.08).cgColor,
        UIColor(white: 1.0, alpha: 0.0).cgColor,
        UIColor(white: 0.0, alpha: 0.05).cgColor
      ];
      bezelLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.15).cgColor;
    } else {
      glassBodyLayer.colors = [
        UIColor(white: 1.0, alpha: 0.35).cgColor,
        UIColor(white: 1.0, alpha: 0.1).cgColor,
        UIColor(white: 0.0, alpha: 0.02).cgColor
      ];
      bezelLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.45).cgColor;
    }
    
    backgroundColor = normalBackgroundColor;
    layer.borderColor = layer.borderColor;
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
    
    // 애니메이션 중에는 래스터화를 꺼야 부드럽게 표현됨
    layer.shouldRasterize = false;
    
    UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
      if self.isHighlighted {
        self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92);
        self.bezelLayer.opacity = 0;
        if isDark { self.alpha = 0.7; }
        else { self.backgroundColor = UIColor(white: 0.0, alpha: 0.15); }
      } else {
        self.transform = .identity;
        self.bezelLayer.opacity = 1.0;
        self.alpha = 1.0;
        self.backgroundColor = self.normalBackgroundColor;
      }
    }, completion: { _ in
      // 애니메이션 완료 후 다시 래스터화 활성화하여 성능 확보
      if !self.isHighlighted {
        self.layer.shouldRasterize = true;
      }
    });
  }
}
