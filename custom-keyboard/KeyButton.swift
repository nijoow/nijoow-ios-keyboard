//
//  KeyButton.swift
//  custom-keyboard
//

import UIKit

class KeyButton: UIButton {
  var keyValue: String = "";
  var touchAreaInsets: UIEdgeInsets = .zero;
  
  // MARK: - 3D Glass 효과 레이어
  
  private let glassBodyLayer = CAGradientLayer();
  private let bezelLayer = CALayer(); // 상단 반사광 엣지
  
  /// 버튼의 기본 배경색 (하이라이트 해제 시 복구용)
  var normalBackgroundColor: UIColor? {
    didSet {
      if !isHighlighted {
        updateLayerColors();
      }
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
    glassBodyLayer.colors = [
      UIColor(white: 1.0, alpha: 0.08).cgColor,
      UIColor(white: 1.0, alpha: 0.0).cgColor,
      UIColor(white: 0.0, alpha: 0.05).cgColor
    ];
    glassBodyLayer.locations = [0.0, 0.4, 1.0];
    glassBodyLayer.startPoint = CGPoint(x: 0.5, y: 0.0);
    glassBodyLayer.endPoint = CGPoint(x: 0.5, y: 1.0);
    layer.insertSublayer(glassBodyLayer, at: 0);
    
    // 2. 상단 베젤 하이라이트 (유리 엣지 반사)
    bezelLayer.backgroundColor = UIColor(white: 1.0, alpha: 0.15).cgColor;
    layer.addSublayer(bezelLayer);
    
    // 기본 레이어 설정
    layer.masksToBounds = true;
  }
  
  override func layoutSubviews() {
    super.layoutSubviews();
    
    CATransaction.begin();
    CATransaction.setDisableActions(true);
    
    let radius = layer.cornerRadius;
    glassBodyLayer.frame = bounds;
    glassBodyLayer.cornerRadius = radius;
    
    // 상단 0.8pt 두께의 아주 미세한 하이라이트 라인
    bezelLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.8);
    bezelLayer.cornerRadius = radius;
    
    CATransaction.commit();
  }
  
  private func updateLayerColors() {
    backgroundColor = normalBackgroundColor;
    // 배경색에 따라 하이라이트 농도를 미세하게 조절할 수 있습니다.
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
    
    UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
      if self.isHighlighted {
        // 공통: 버튼 살짝 축소 및 깊이감 증가
        self.transform = CGAffineTransform(scaleX: 0.94, y: 0.94);
        self.bezelLayer.opacity = 0; // 눌렸을 때 상단 하이라이트 제거로 깊이감 표현
        
        if isDark {
          self.alpha = 0.7;
        } else {
          self.backgroundColor = UIColor(white: 0.0, alpha: 0.15);
        }
      } else {
        self.transform = .identity;
        self.bezelLayer.opacity = 1.0;
        self.alpha = 1.0;
        self.backgroundColor = self.normalBackgroundColor;
      }
    }, completion: nil);
  }
}
