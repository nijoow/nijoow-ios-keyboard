import UIKit
import XCTest

@MainActor
final class KeyButtonGeometryTests: XCTestCase {
  func testTouchExpansionWaitsForNonzeroFittedContainer() {
    let container = KeyboardHitAreaView(frame: CGRect(x: 0, y: 0, width: 390, height: 0))
    let row = ExpandedHitView(frame: CGRect(x: 6, y: 6, width: 378, height: 44))
    let key = KeyButton(frame: CGRect(x: 0, y: 0, width: 30, height: 44))
    key.keyValue = "a"
    row.addSubview(key)
    row.registerKey(key)
    container.addSubview(row)
    container.keyRows = [row]
    container.updateKeyTouchAreas()
    XCTAssertEqual(container.touchAreaUpdateCount, 0)
    XCTAssertEqual(key.touchExpansion, .zero)
    container.frame.size.height = 20
    container.updateKeyTouchAreas()
    XCTAssertEqual(container.touchAreaUpdateCount, 0)
    container.frame.size.height = 56
    container.updateKeyTouchAreas()
    XCTAssertEqual(container.touchAreaUpdateCount, 1)
    for _ in 0..<100 { container.updateKeyTouchAreas() }
    XCTAssertLessThanOrEqual(container.touchAreaUpdateCount, 3)
  }

  func testTouchFrameExpandsWhileVisibleKeyStaysInPlace() {
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let key = KeyButton(type: .custom)
    key.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(key)
    NSLayoutConstraint.activate([
      key.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 25),
      key.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
      key.widthAnchor.constraint(equalToConstant: 40),
      key.heightAnchor.constraint(equalToConstant: 44),
    ])
    container.layoutIfNeeded()
    let original = key.convert(key.visualBounds, to: container)
    key.expandTouchArea(UIEdgeInsets(top: 2.5, left: 25, bottom: 2.5, right: 1.5))
    container.layoutIfNeeded()
    XCTAssertEqual(key.convert(key.visualBounds, to: container), original)
    XCTAssertEqual(key.frame.minX, 0, accuracy: 0.01)
    XCTAssertTrue(key.bounds.contains(key.convert(CGPoint(x: 1, y: 40), from: container)))
  }
}
