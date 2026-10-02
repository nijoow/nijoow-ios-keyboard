import UIKit
import XCTest

@MainActor
final class KeyboardHostIntegrationTests: XCTestCase {
  func testBackgroundAndActiveWithoutAppearanceCallbacksKeepKeyboardUsable() {
    let keyboard = makeKeyboard()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.addSubview(keyboard.view)
    keyboard.viewWillDisappear(false)
    keyboard.viewDidDisappear(false)
    NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostDidEnterBackground, object: nil)
    XCTAssertTrue(keyboard.hasKeyboardViewHierarchy)
    NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil)
    XCTAssertTrue(keyboard.hasKeyboardViewHierarchy)
    XCTAssertTrue(keyboard.isKeyboardVisible)
    XCTAssertTrue(keyboard.dispatchKeyboardAction(.character("q")))
    XCTAssertEqual(keyboard.proxy.text, "ㅂ")
    keyboard.view.removeFromSuperview()
  }

  func testMemoryPressureDuringBackgroundRebuildsOnHostActivation() {
    let keyboard = makeKeyboard()
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.addSubview(keyboard.view)
    NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostDidEnterBackground, object: nil)
    keyboard.didReceiveMemoryWarning()
    XCTAssertFalse(keyboard.hasKeyboardViewHierarchy)
    NotificationCenter.default.post(name: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil)
    XCTAssertTrue(keyboard.hasKeyboardViewHierarchy)
    keyboard.view.removeFromSuperview()
  }

  func testNumericTraitsRebuildPadAndRestoreTextKeyboard() {
    let keyboard = makeKeyboard(type: .numberPad)
    XCTAssertEqual(keyboard.allKeyButtons.filter { Int($0.keyValue) != nil }.count, 10)
    XCTAssertNil(keyboard.spaceButton)
    XCTAssertFalse(keyboard.allKeyButtons.contains { $0.keyValue == "q" })
    keyboard.dispatchKeyboardAction(.character("1"))
    keyboard.dispatchKeyboardAction(.backspace)
    XCTAssertEqual(keyboard.proxy.text, "")

    keyboard.proxy.keyboardType = .decimalPad
    keyboard.textDidChange(nil)
    keyboard.view.layoutIfNeeded()
    XCTAssertTrue(keyboard.allKeyButtons.contains { $0.keyValue == (Locale.current.decimalSeparator ?? ".") })

    keyboard.proxy.documentIdentifier = UUID()
    keyboard.proxy.keyboardType = .default
    keyboard.textDidChange(nil)
    keyboard.view.layoutIfNeeded()
    XCTAssertNotNil(keyboard.spaceButton)
    XCTAssertTrue(keyboard.allKeyButtons.contains { $0.keyValue == "q" })
  }

  func testNumericSymbolToggleReusesKeysAndRoutesSymbolInput() {
    let keyboard = makeKeyboard(type: .numberPad)
    let originalKeys = keyboard.allKeyButtons
    let toggle = originalKeys.first { $0.keyValue == KeyboardConstants.KeyID.symbol }!
    let zero = originalKeys.first { $0.keyValue == "0" }!
    let delete = originalKeys.first { $0.keyValue == KeyboardConstants.KeyID.backspace }!
    XCTAssertEqual(toggle.title(for: .normal), "#+=")
    XCTAssertEqual(toggle.visualBounds.width, zero.visualBounds.width, accuracy: 0.5)
    XCTAssertEqual(delete.visualBounds.width, zero.visualBounds.width, accuracy: 0.5)
    let originalState = keyboard.interactionState

    toggle.sendActions(for: .touchUpInside)
    keyboard.view.layoutIfNeeded()
    XCTAssertEqual(toggle.title(for: .normal), "123")
    XCTAssertEqual(toggle.accessibilityLabel, "숫자 키패드로 전환")
    for symbol in ["*", "#", ".", ",", "+", "-", "/", "(", ")", "0"] {
      let key = keyboard.allKeyButtons.first { $0.keyValue == symbol }!
      keyboard.keyButtonTouchesBegan(key)
    }
    XCTAssertEqual(keyboard.proxy.text, "*#.,+-/()0")
    keyboard.dispatchKeyboardAction(.backspace)
    XCTAssertEqual(keyboard.proxy.text, "*#.,+-/()")
    XCTAssertTrue(toggle.accessibilityActivate())
    XCTAssertEqual(toggle.title(for: .normal), "#+=")
    for _ in 0..<100 { toggle.sendActions(for: .touchUpInside) }
    XCTAssertEqual(keyboard.allKeyButtons.count, originalKeys.count)
    XCTAssertTrue(zip(originalKeys, keyboard.allKeyButtons).allSatisfy { $0 === $1 })
    XCTAssertEqual(keyboard.interactionState, originalState)
    XCTAssertEqual(keyboard.allKeyButtons.filter { Int($0.keyValue) != nil }.count, 10)
  }

  func testNumericSymbolsResetOnDocumentChange() {
    let keyboard = makeKeyboard(type: .numberPad)
    keyboard.dispatchKeyboardAction(.toggleSymbols)
    XCTAssertTrue(keyboard.showsNumericSymbols)
    keyboard.buildKeyboard()
    XCTAssertTrue(keyboard.allKeyButtons.contains { $0.keyValue == "*" })
    keyboard.proxy.documentIdentifier = UUID()
    keyboard.textDidChange(nil)
    keyboard.view.layoutIfNeeded()
    XCTAssertFalse(keyboard.showsNumericSymbols)
    XCTAssertTrue(keyboard.allKeyButtons.contains { $0.keyValue == "1" })
  }

  func testOversizedHostDoesNotStretchKeyContent() {
    let keyboard = makeKeyboard()
    let target = keyboard.desiredKeyboardHeight
    let systemHeight = keyboard.view.heightAnchor.constraint(equalToConstant: target + 200)
    systemHeight.isActive = true
    keyboard.view.layoutIfNeeded()
    XCTAssertEqual(keyboard.keyboardContentView.bounds.height, target, accuracy: 0.5)
    XCTAssertEqual(keyboard.keyboardContentView.frame.maxY, keyboard.view.bounds.height, accuracy: 0.5)
    systemHeight.isActive = false
  }

  func testHiddenAndDisabledRowsCannotRouteTouches() {
    let row = ExpandedHitStackView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
    let key = KeyButton(frame: CGRect(x: 10, y: 0, width: 40, height: 50))
    key.keyValue = "a"
    row.addSubview(key)
    row.registerKey(key)
    row.isHidden = true
    XCTAssertNil(row.hitTest(CGPoint(x: 3, y: 20), with: nil))
    row.isHidden = false
    row.isUserInteractionEnabled = false
    XCTAssertNil(row.hitTest(CGPoint(x: 3, y: 20), with: nil))
  }

  func testEndKeyMarginsAndBackspaceCenterRouteToExpectedKeys() {
    let keyboard = makeKeyboard()
    for id in ["a", "l", "backspace"] {
      let key = keyboard.allKeyButtons.first { $0.keyValue == id }!
      let frame = key.convert(key.visualBounds, to: keyboard.view)
      let x: CGFloat = id == "a" ? 1 : (id == "l" ? 389 : frame.midX)
      XCTAssertTrue(keyboard.view.hitTest(CGPoint(x: x, y: frame.midY), with: nil) === key, id)
    }
  }

  func testLegacyCompositionKeepsPreviousSyllablesAndDeletesJamo() {
    let keyboard = makeKeyboard()
    for key in ["r", "k", "s", "k", "e", "k"] {
      keyboard.dispatchKeyboardAction(.character(key))
      keyboard.textDidChange(nil)
    }
    XCTAssertEqual(keyboard.proxy.text, "가나다")
    XCTAssertGreaterThan(keyboard.proxy.ordinaryDeleteCount, 0)
    XCTAssertEqual(keyboard.proxy.markedUpdateCount, 0)
    keyboard.dispatchKeyboardAction(.backspace)
    // 기존 자모 스택 방식에서는 마지막 모음을 지우면 ㄷ이 앞 음절의 종성으로 재조합된다.
    XCTAssertEqual(keyboard.proxy.text, "가낟")
    keyboard.dispatchKeyboardAction(.space)
    XCTAssertEqual(keyboard.proxy.text, "가낟 ")
  }

  func testSecondRowSideWhitespaceRoutesAndTypesAtMultipleWidths() {
    for width: CGFloat in [320, 390, 430, 844, 1024] {
      let keyboard = makeKeyboard(width: width)
      for (id, expected) in [("a", "ㅁ"), ("l", "ㅣ")] {
        let key = keyboard.allKeyButtons.first { $0.keyValue == id }!
        let frame = key.convert(key.visualBounds, to: keyboard.view)
        let xs: [CGFloat] = id == "a"
          ? [0.5, 5, frame.minX - 0.5]
          : [frame.maxX + 0.5, width - 5, width - 0.5]
        for x in xs {
          for y in [frame.minY + 0.5, frame.midY, frame.maxY - 0.5] {
            let hit = keyboard.view.hitTest(CGPoint(x: x, y: y), with: nil) as? KeyButton
            XCTAssertTrue(hit === key, "\(width) \(id): \(x),\(y)")
            XCTAssertTrue(key.bounds.contains(key.convert(CGPoint(x: x, y: y), from: keyboard.view)),
                          "여백 터치가 실제 UIButton 프레임에 포함돼야 한다: \(width), \(id)")
            keyboard.flushHangul()
            keyboard.proxy.replaceDocument(with: "")
            if let hit { keyboard.keyButtonTouchesBegan(hit) }
            XCTAssertEqual(keyboard.proxy.text, expected)
          }
        }
      }
    }
  }

  func testEveryHorizontalLetterGapRoutesToCloserKey() {
    let keyboard = makeKeyboard()
    for tags in [300...309, 400...409, 500...508, 600...606] {
      let keys = keyboard.allKeyButtons.filter { tags.contains($0.tag) }.sorted { $0.tag < $1.tag }
      for (left, right) in zip(keys, keys.dropFirst()) {
        let lhs = left.convert(left.visualBounds, to: keyboard.view)
        let rhs = right.convert(right.visualBounds, to: keyboard.view)
        for (fraction, expected) in [(CGFloat(0.25), left), (CGFloat(0.75), right)] {
          let point = CGPoint(x: lhs.maxX + (rhs.minX - lhs.maxX) * fraction, y: lhs.midY)
          XCTAssertTrue(keyboard.view.hitTest(point, with: nil) === expected)
          XCTAssertTrue(expected.bounds.contains(expected.convert(point, from: keyboard.view)))
        }
      }
    }
  }

  func testNumericOuterAndSectionWhitespaceRoutesToKeys() {
    let keyboard = makeKeyboard(type: .numberPad)
    let one = keyboard.allKeyButtons.first { $0.keyValue == "1" }!
    let frame = one.convert(one.visualBounds, to: keyboard.view)
    XCTAssertTrue(keyboard.view.hitTest(CGPoint(x: 1, y: 1), with: nil) === one)
    XCTAssertTrue(keyboard.view.hitTest(CGPoint(x: frame.midX, y: frame.minY - 1), with: nil) === one)
    let grid = keyboard.mainContentStack!
    let gridFrame = grid.convert(grid.bounds, to: keyboard.view)
    let zero = keyboard.allKeyButtons.first { $0.keyValue == "0" }!
    let zeroFrame = zero.convert(zero.visualBounds, to: keyboard.view)
    XCTAssertTrue(keyboard.view.hitTest(CGPoint(x: zeroFrame.midX, y: gridFrame.maxY + 1), with: nil) === zero)
  }

  func testTouchCellsDoNotOverlapOrDriftAcrossRepeatedLayouts() {
    let keyboard = makeKeyboard()
    let keys = keyboard.allKeyButtons.filter { $0.keyValue != KeyboardConstants.KeyID.dummy }
    let originals = keys.map { $0.convert($0.visualBounds, to: keyboard.view) }
    let updateCount = keyboard.keyboardContentView.touchAreaUpdateCount
    for _ in 0..<100 {
      keyboard.view.setNeedsLayout()
      keyboard.view.layoutIfNeeded()
    }
    XCTAssertLessThanOrEqual(keyboard.keyboardContentView.touchAreaUpdateCount, updateCount + 2)
    for (key, original) in zip(keys, originals) {
      XCTAssertEqual(key.convert(key.visualBounds, to: keyboard.view).minX, original.minX, accuracy: 0.1)
      XCTAssertEqual(key.convert(key.visualBounds, to: keyboard.view).width, original.width, accuracy: 0.1)
    }
    for (index, key) in keys.enumerated() {
      let frame = key.convert(key.bounds, to: keyboard.view)
      for other in keys.dropFirst(index + 1) {
        let intersection = frame.intersection(other.convert(other.bounds, to: keyboard.view))
        XCTAssertTrue(intersection.isNull || intersection.width < 0.1 || intersection.height < 0.1,
                      "터치 영역 겹침: \(key.keyValue), \(other.keyValue)")
      }
    }
  }

  func testHiddenRowsAndSpaceDragOverlayKeepBlockingFallbackRouting() {
    let keyboard = makeKeyboard()
    let key = keyboard.allKeyButtons.first { $0.keyValue == "a" }!
    let frame = key.convert(key.visualBounds, to: keyboard.view)
    keyboard.mainContentStack?.isHidden = true
    XCTAssertFalse(keyboard.view.hitTest(CGPoint(x: 1, y: frame.midY), with: nil) is KeyButton)
    keyboard.mainContentStack?.isHidden = false
    keyboard.beginSpaceCursorMode()
    XCTAssertTrue(keyboard.view.hitTest(CGPoint(x: 1, y: frame.midY), with: nil) is SpaceDragOverlayView)
  }

  func testDeletingEntireCompositionResetsContextForNextWord() {
    let keyboard = makeKeyboard()
    keyboard.dispatchKeyboardAction(.character("r"))
    keyboard.dispatchKeyboardAction(.backspace)
    XCTAssertTrue(keyboard.composedText.isEmpty)
    keyboard.dispatchKeyboardAction(.character("s"))
    keyboard.dispatchKeyboardAction(.character("k"))
    XCTAssertEqual(keyboard.proxy.text, "나")
  }

  func testEveryIntermediateSyllablePreservesEarlierLetters() {
    let keyboard = makeKeyboard()
    let expected = ["ㄱ", "가", "간", "가나", "가낟", "가나다"]
    for (key, text) in zip(["r", "k", "s", "k", "e", "k"], expected) {
      keyboard.dispatchKeyboardAction(.character(key))
      keyboard.textDidChange(nil)
      XCTAssertEqual(keyboard.proxy.text, text)
    }
    XCTAssertEqual(keyboard.proxy.markedUpdateCount, 0)
  }

  func testContinuousTypingDoesNotReplacePreviousWords() {
    let keyboard = makeKeyboard()
    for _ in 0..<100 {
      for key in ["r", "k", "s", "k", "e", "k"] {
        keyboard.dispatchKeyboardAction(.character(key))
        keyboard.selectionDidChange(nil)
      }
    }
    XCTAssertEqual(keyboard.proxy.text, String(repeating: "가나다", count: 100))
    XCTAssertEqual(keyboard.proxy.markedUpdateCount, 0)
  }

  func testDocumentSwitchDoesNotReplaceTextInNewField() {
    let keyboard = makeKeyboard()
    keyboard.dispatchKeyboardAction(.character("r"))
    keyboard.dispatchKeyboardAction(.character("k"))
    keyboard.proxy.documentIdentifier = UUID()
    keyboard.proxy.replaceDocument(with: "새 입력: ")
    keyboard.dispatchKeyboardAction(.character("s"))
    keyboard.dispatchKeyboardAction(.character("k"))
    XCTAssertEqual(keyboard.proxy.text, "새 입력: 나")
  }

  func testNativeTextFieldKeepsEarlierSyllablesWithLegacyInput() {
    let keyboard = makeKeyboard()
    let field = UITextField()
    keyboard.proxy.nativeField = field
    for key in ["r", "k", "s", "k", "e", "k", "f", "k"] {
      keyboard.dispatchKeyboardAction(.character(key))
    }
    XCTAssertEqual(field.text, "가나다라")
    keyboard.dispatchKeyboardAction(.backspace)
    XCTAssertEqual(field.text, "가나달")
    XCTAssertNil(field.markedTextRange)
  }

  func testNumericAndTextSnapshots() {
    for type in [UIKeyboardType.default, .numberPad, .decimalPad] {
      let keyboard = makeKeyboard(type: type)
      let renderer = UIGraphicsImageRenderer(bounds: keyboard.view.bounds)
      let image = renderer.image { keyboard.view.layer.render(in: $0.cgContext) }
      let attachment = XCTAttachment(image: image)
      attachment.name = type == .default ? "text-keyboard" : (type == .numberPad ? "number-keyboard" : "decimal-keyboard")
      attachment.lifetime = .keepAlways
      add(attachment)
      if type == .numberPad {
        keyboard.dispatchKeyboardAction(.toggleSymbols)
        keyboard.view.layoutIfNeeded()
        let symbols = renderer.image { keyboard.view.layer.render(in: $0.cgContext) }
        let attachment = XCTAttachment(image: symbols)
        attachment.name = "numeric-symbol-keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
      }
    }
  }

  private func makeKeyboard(type: UIKeyboardType = .default, width: CGFloat = 390) -> TestKeyboardController {
    let keyboard = TestKeyboardController()
    keyboard.proxy.keyboardType = type
    keyboard.loadViewIfNeeded()
    keyboard.view.frame = CGRect(x: 0, y: 0, width: width, height: keyboard.desiredKeyboardHeight)
    keyboard.viewWillAppear(false)
    keyboard.view.layoutIfNeeded()
    return keyboard
  }
}

@MainActor
private final class TestKeyboardController: KeyboardViewController {
  let proxy = TestDocumentProxy()
  override var textDocumentProxy: any UITextDocumentProxy { proxy }
}

@MainActor
private final class TestDocumentProxy: NSObject, UITextDocumentProxy {
  var documentIdentifier = UUID()
  var keyboardType: UIKeyboardType = .default
  var documentInputMode: UITextInputMode? { nil }
  var selectedText: String? { nil }
  var nativeField: UITextField?
  var documentContextBeforeInput: String? { text }
  var documentContextAfterInput: String? { "" }
  var hasText: Bool { !text.isEmpty }
  private var committed = ""
  private var marked = ""
  private(set) var ordinaryDeleteCount = 0
  private(set) var markedUpdateCount = 0
  var text: String { nativeField?.text ?? (committed + marked) }

  func replaceDocument(with text: String) { committed = text; marked = "" }
  func insertText(_ text: String) {
    if let nativeField { nativeField.insertText(text); return }
    committed += marked + text
    marked = ""
  }
  func deleteBackward() {
    ordinaryDeleteCount += 1
    if let nativeField { nativeField.deleteBackward(); return }
    unmarkText()
    if !committed.isEmpty { committed.removeLast() }
  }
  func adjustTextPosition(byCharacterOffset offset: Int) { unmarkText() }
  func setMarkedText(_ markedText: String, selectedRange: NSRange) {
    markedUpdateCount += 1
    marked = markedText
  }
  func unmarkText() { committed += marked; marked = "" }
}
