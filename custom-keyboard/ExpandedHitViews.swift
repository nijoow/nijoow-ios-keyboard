import UIKit

/// 실제 키가 선택되지 않은 키보드 외곽 여백만 가장 가까운 행의 키로 보정한다.
/// 일반 터치는 기존 UIKit 경로를 사용하고, 여백에서만 행과 해당 행의 키를 탐색한다.
final class KeyboardHitAreaView: UIView {
  var keyRows: [UIView] = [] {
    didSet { appliedTouchLayout = nil }
  }
  private struct TouchLayout: Equatable {
    let size: CGSize
    let enabledKeys: [Bool]
  }
  private var appliedTouchLayout: TouchLayout?
  private var settlingPasses = 0
  private(set) var touchAreaUpdateCount = 0

  /// 각 키가 행 간격의 절반과 좌우 이웃 사이의 절반을 소유한다.
  /// 첫/마지막 키는 키보드 끝까지 소유하므로 9키 행의 더미 공간도 실제 터치 프레임에 포함된다.
  func updateKeyTouchAreas() {
    guard bounds.width > 0, bounds.height > 0, !keyRows.isEmpty else { return }
    let rows = keyRows.map { row -> (frame: CGRect, keys: [KeyButton]) in
      let keys: [KeyButton]
      if let row = row as? ExpandedHitView { keys = row.registeredKeys }
      else if let row = row as? ExpandedHitStackView { keys = row.registeredKeys }
      else { keys = [] }
      return (row.convert(row.bounds, to: self), keys)
    }
    // 임시 프레임에서 alignment inset을 변경해 호스트의 크기 협상을 반복시키지 않는다.
    guard rows.allSatisfy({ row in
      row.frame.width > 0 && row.frame.height > 0
        && row.frame.minY >= bounds.minY - 0.5 && row.frame.maxY <= bounds.maxY + 0.5
        && row.keys.filter { !$0.isHidden && $0.isUserInteractionEnabled && $0.alpha > 0.01 }
          .allSatisfy { $0.visualBounds.width > 0 && $0.visualBounds.height > 0 }
    }) else { return }
    let size = CGSize(width: (bounds.width * 2).rounded() / 2, height: (bounds.height * 2).rounded() / 2)
    let layout = TouchLayout(size: size, enabledKeys: rows.flatMap { row in
      row.keys.map { !$0.isHidden && $0.isUserInteractionEnabled && $0.alpha > 0.01 }
    })
    if appliedTouchLayout != layout {
      appliedTouchLayout = layout
      settlingPasses = 0
    }
    // 정렬 inset 적용 뒤 스택이 확정되는 보정은 허용하되 같은 크기에서 3회를 넘기지 않는다.
    guard settlingPasses < 3 else { return }
    settlingPasses += 1
    touchAreaUpdateCount += 1
    for (index, row) in keyRows.enumerated() {
      let rowFrame = row.convert(row.bounds, to: self)
      guard rowFrame.width > 0, rowFrame.height > 0 else { continue }
      let previous = index > 0 ? keyRows[index - 1] : nil
      let next = index + 1 < keyRows.count ? keyRows[index + 1] : nil
      let top = previous.map { ($0.convert($0.bounds, to: self).maxY + rowFrame.minY) / 2 } ?? bounds.minY
      let bottom = next.map { ($0.convert($0.bounds, to: self).minY + rowFrame.maxY) / 2 } ?? bounds.maxY
      let keys: [KeyButton]
      if let row = row as? ExpandedHitView { keys = row.registeredKeys }
      else if let row = row as? ExpandedHitStackView { keys = row.registeredKeys }
      else { continue }
      let visible = keys.filter { !$0.isHidden && $0.isUserInteractionEnabled && $0.alpha > 0.01 }
        .map { (key: $0, frame: $0.convert($0.visualBounds, to: self)) }
        .sorted { $0.frame.minX < $1.frame.minX }
      for (i, item) in visible.enumerated() {
        guard item.key.acceptsGapHitRouting else { continue }
        let left = i == 0 ? bounds.minX : (visible[i - 1].frame.maxX + item.frame.minX) / 2
        let right = i + 1 == visible.count ? bounds.maxX : (item.frame.maxX + visible[i + 1].frame.minX) / 2
        item.key.expandTouchArea(UIEdgeInsets(
          top: max(0, item.frame.minY - top), left: max(0, item.frame.minX - left),
          bottom: max(0, bottom - item.frame.maxY), right: max(0, right - item.frame.maxX)))
      }
    }
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hit = super.hitTest(point, with: event) else { return nil }
    // 이모지 스크롤·팝업 같은 별도 UI가 받은 터치를 문자 키로 바꾸지 않는다.
    guard hit === self else { return hit }

    let nearestRow = keyRows.min { lhs, rhs in
      verticalDistance(to: lhs, from: point) < verticalDistance(to: rhs, from: point)
    }
    guard let row = nearestRow, isVisibleForHitTesting(row) else { return self }
    let localPoint = convert(point, to: row)
    if let row = row as? ExpandedHitView {
      return row.nearestRegisteredKey(at: localPoint) ?? self
    }
    if let row = row as? ExpandedHitStackView {
      return row.nearestRegisteredKey(at: localPoint) ?? self
    }
    return self
  }

  private func verticalDistance(to row: UIView, from point: CGPoint) -> CGFloat {
    let frame = row.convert(row.bounds, to: self)
    return max(frame.minY - point.y, 0, point.y - frame.maxY)
  }

  private func isVisibleForHitTesting(_ row: UIView) -> Bool {
    var ancestor: UIView? = row
    while let view = ancestor, view !== self {
      guard !view.isHidden, view.isUserInteractionEnabled, view.alpha > 0.01 else { return false }
      ancestor = view.superview
    }
    return ancestor === self
  }
}

/// 행 안의 실제 키만 명시적으로 보관한다. 일반 버튼 터치는 UIKit이 바로 처리하고,
/// 버튼 사이·행 바깥 여백에서만 이 목록을 사용해 가장 가까운 키를 고른다.
private final class KeyHitMap {
  private(set) var keys: [KeyButton] = []

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

    // 가장 가까운 실제 키가 시스템 상태를 바꾸는 키라면, 그 키를 건너뛰고 더 먼
    // 일반 키로 보내지 않는다. 여백 터치는 그대로 소비하고 직접 탭만 UIKit에 맡긴다.
    return nearest?.acceptsGapHitRouting == true ? nearest : nil
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
  fileprivate var registeredKeys: [KeyButton] { keyHitMap.keys }

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
    guard !isHidden, isUserInteractionEnabled, alpha > 0.01 else { return nil }
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
  fileprivate var registeredKeys: [KeyButton] { keyHitMap.keys }

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
    guard !isHidden, isUserInteractionEnabled, alpha > 0.01 else { return nil }
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
