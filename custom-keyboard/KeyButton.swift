//
//  KeyButton.swift
//  custom-keyboard
//

import UIKit

class KeyButton: UIButton {
  var keyValue: String = ""
  
  /// 버튼의 기본 배경색 (하이라이트 해제 시 복구용)
  var normalBackgroundColor: UIColor? {
    didSet {
      if !isHighlighted {
        backgroundColor = normalBackgroundColor
      }
    }
  }
  
  // MARK: - 히트 테스트 영역 최적화
  
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // 시스템 제스처(엣지 스와이프 등) 간섭을 최소화하기 위해 터치 영역을 꽉 채워 인식하도록 함
    // 버튼의 시각적 범위(bounds) 내에 있다면 무조건 true 반환
    return bounds.contains(point)
  }
  
  // MARK: - 터치 피드백 (하이라이트 효과)
  
  override var isHighlighted: Bool {
    didSet {
      guard oldValue != isHighlighted else { return }
      updateHighlightState()
    }
  }
  
  private func updateHighlightState() {
    let isDark = traitCollection.userInterfaceStyle == .dark
    
    // 터치 즉시 반응을 위해 애니메이션 시간을 짧게 설정 (0.1초)
    UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: {
      if self.isHighlighted {
        // 공통: 버튼 살짝 축소
        self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        if isDark {
          // 다크 모드: 기존처럼 살짝 흐려지게 (0.7 alpha)
          self.alpha = 0.7
        } else {
          // 라이트 모드: 어두워지는 효과 (검은색 투명 레이어 느낌)
          self.backgroundColor = UIColor(white: 0.0, alpha: 0.15)
        }
      } else {
        // 복구: 원래 상태로
        self.transform = .identity
        self.alpha = 1.0
        self.backgroundColor = self.normalBackgroundColor
      }
    }, completion: nil)
  }
}

