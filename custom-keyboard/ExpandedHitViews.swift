import UIKit

/// 행 안의 실제 키만 명시적으로 보관한다. 일반 버튼 터치는 UIKit이 바로 처리하고,
/// 버튼 사이·행 바깥 여백에서만 이 목록을 사용해 가장 가까운 키를 고른다.
private final class KeyHitMap {
  private var keys: [KeyButton] = []

  func register(_ key: KeyButton) {
    guard key.keyValue != KeyboardConstants.KeyID.dummy,
      !keys.contains(where: { $0 === key })
    else { return }
    keys.append(key)
  }

  func nearestKey(to point: CGPoint, in container: UIView) -> KeyButton? {
    var nearest: KeyButton?
    var nearestDistance = CGFloat.greatestFiniteMagnitude

    for key in keys
    where key.isUserInteractionEnabled && !key.isHidden && key.alpha > 0.01 {
      let frame = key.convert(key.bounds, to: container)
      let distance = squaredDistance(from: point, to: frame)
      if distance < nearestDistance {
        nearest = key
        nearestDistance = distance
        if distance == 0 { break }
      }
    }

    return nearest
  }

  private func squaredDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
    let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
    let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
    return dx * dx + dy * dy
  }
}

/// 키 사이 여백과 행 바깥의 작은 여백까지 가장 가까운 키로 전달하는 컨테이너.
final class ExpandedHitView: UIView {
  /// 음수 inset만큼 컨테이너 바깥 터치를 받아 가장 가까운 키로 전달한다.
  /// 세로값은 행 사이에서 겹치지 않도록 레이아웃을 만드는 쪽에서 필요한 경우만 지정한다.
  var hitTestInsets = UIEdgeInsets(
    top: 0,
    left: -KeyboardConstants.Interaction.horizontalHitSlop,
    bottom: 0,
    right: -KeyboardConstants.Interaction.horizontalHitSlop
  )
  private let keyHitMap = KeyHitMap()

  func registerKey(_ key: KeyButton) {
    keyHitMap.register(key)
  }

  fileprivate func nearestRegisteredKey(at point: CGPoint) -> KeyButton? {
    keyHitMap.nearestKey(to: point, in: self)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.inset(by: hitTestInsets).contains(point)
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard self.point(inside: point, with: event) else { return nil }

    // 실제 버튼 내부는 UIKit 기본 hit-test 결과를 그대로 사용한다.
    if let directKey = super.hitTest(point, with: event) as? KeyButton {
      return directKey
    }

    // 기본 경로가 키를 찾지 못한 여백에서만 같은 행의 등록 키를 보정한다.
    return nearestRegisteredKey(at: point) ?? self
  }
}

/// `UIStackView` 안의 키 사이 여백을 결정적으로 라우팅하는 스택 뷰.
final class ExpandedHitStackView: UIStackView {
  var hitTestInsets = UIEdgeInsets(
    top: 0,
    left: -KeyboardConstants.Interaction.horizontalHitSlop,
    bottom: 0,
    right: -KeyboardConstants.Interaction.horizontalHitSlop
  )
  private let keyHitMap = KeyHitMap()

  func registerKey(_ key: KeyButton) {
    keyHitMap.register(key)
  }

  fileprivate func nearestRegisteredKey(at point: CGPoint) -> KeyButton? {
    keyHitMap.nearestKey(to: point, in: self)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    bounds.inset(by: hitTestInsets).contains(point)
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard self.point(inside: point, with: event) else { return nil }

    if let directKey = super.hitTest(point, with: event) as? KeyButton {
      return directKey
    }

    if axis == .vertical, let row = nearestArrangedSubview(at: point) {
      return nearestKey(in: row, at: convert(point, to: row)) ?? self
    }

    return nearestRegisteredKey(at: point) ?? self
  }

  private func nearestArrangedSubview(at point: CGPoint) -> UIView? {
    var nearest: UIView?
    var nearestDistance = CGFloat.greatestFiniteMagnitude

    for subview in arrangedSubviews
    where subview.isUserInteractionEnabled && !subview.isHidden && subview.alpha > 0.01 {
      let distance = squaredDistance(from: point, to: subview.frame)
      if distance < nearestDistance {
        nearest = subview
        nearestDistance = distance
        if distance == 0 { break }
      }
    }

    return nearest
  }

  private func nearestKey(in row: UIView, at point: CGPoint) -> KeyButton? {
    if let hitView = row as? ExpandedHitView {
      return hitView.nearestRegisteredKey(at: point)
    }
    if let hitStack = row as? ExpandedHitStackView {
      return hitStack.nearestRegisteredKey(at: point)
    }
    return nil
  }

  private func squaredDistance(from point: CGPoint, to frame: CGRect) -> CGFloat {
    let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
    let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
    return dx * dx + dy * dy
  }
}

/// 스페이스바 드래그(커서 이동) 중 다른 키 위에 깔리는 딤 오버레이.
/// 스페이스바 영역(passthroughRect)만 터치를 통과시키고 나머지 입력은 막는다.
final class SpaceDragOverlayView: UIView {
  var passthroughRect: CGRect = .zero

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    // 스페이스바 영역은 통과(false), 나머지는 가로채서 다른 키 입력을 막는다(true)
    return !passthroughRect.contains(point)
  }
}
