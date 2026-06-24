import UIKit

/// 자식 뷰들의 확장된 터치 영역(touchAreaInsets)까지 이벤트를 전달할 수 있는 컨테이너 뷰
class ExpandedHitView: UIView {
  var hitTestMargin: CGFloat = 8.0; // 상하좌우로 더 허용할 마진
  
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // 기본 bounds에서 hitTestMargin만큼 확장된 영역에 대해 터치 여부 판정
    let expandedBounds = bounds.insetBy(dx: -hitTestMargin, dy: -hitTestMargin);
    return expandedBounds.contains(point);
  }
}

/// 자식 뷰들의 확장된 터치 영역까지 이벤트를 전달할 수 있는 스택 뷰
class ExpandedHitStackView: UIStackView {
  var hitTestMargin: CGFloat = 8.0;

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    let expandedBounds = bounds.insetBy(dx: -hitTestMargin, dy: -hitTestMargin);
    return expandedBounds.contains(point);
  }
}

/// 스페이스바 드래그(커서 이동) 중 다른 키 위에 깔리는 딤 오버레이.
/// 스페이스바 영역(passthroughRect)만 터치를 통과시키고 나머지 입력은 막는다.
class SpaceDragOverlayView: UIView {
  var passthroughRect: CGRect = .zero;

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // 스페이스바 영역은 통과(false), 나머지는 가로채서 다른 키 입력을 막는다(true)
    return !passthroughRect.contains(point);
  }
}
