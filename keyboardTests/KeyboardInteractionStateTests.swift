import XCTest

@MainActor
final class KeyboardInteractionStateTests: XCTestCase {
  func testCharacterBetweenShiftTapsPreventsUnexpectedShiftLock() {
    var state = KeyboardInteractionState()
    state.tapShift(at: 10, doubleTapInterval: 0.3)

    XCTAssertEqual(state.shift, .oneShot)
    XCTAssertTrue(state.consumeOneShotShift())
    state.cancelShiftTapCandidate()
    state.tapShift(at: 10.2, doubleTapInterval: 0.3)

    XCTAssertEqual(state.shift, .oneShot)
    XCTAssertFalse(state.isShiftLocked)
  }

  func testConsecutiveShiftTapsEnableLock() {
    var state = KeyboardInteractionState()
    state.tapShift(at: 10, doubleTapInterval: 0.3)
    state.tapShift(at: 10.2, doubleTapInterval: 0.3)

    XCTAssertEqual(state.shift, .locked)
    XCTAssertTrue(state.isShiftLocked)
  }

  func testPanelTransitionsCannotKeepHiddenShiftState() {
    var state = KeyboardInteractionState()
    state.tapShift(at: 1, doubleTapInterval: 0.3)
    state.toggleEmoji()

    XCTAssertEqual(state.panel, .emoji)
    XCTAssertEqual(state.shift, .off)

    state.toggleSymbols()
    XCTAssertEqual(state.panel, .symbols(.primary))
    state.tapShift(at: 2, doubleTapInterval: 0.3)
    XCTAssertEqual(state.panel, .symbols(.secondary))
  }

  func testActionActivationPoliciesMatchTypingContract() {
    XCTAssertEqual(KeyboardAction.character("a").activationPolicy, .pressDown)
    XCTAssertEqual(KeyboardAction.backspace.activationPolicy, .pressDown)
    XCTAssertEqual(KeyboardAction.space.activationPolicy, .releaseInside)
    XCTAssertEqual(KeyboardAction.switchLanguage.activationPolicy, .releaseInside)
  }

  func testBackspaceProfileAcceleratesByIncreasingBatchSize() {
    let initial = BackspaceRepeatProfile.profile(heldDuration: 0.5)
    let medium = BackspaceRepeatProfile.profile(heldDuration: 2.0)
    let fast = BackspaceRepeatProfile.profile(heldDuration: 3.5)
    let fastest = BackspaceRepeatProfile.profile(heldDuration: 8.0)

    XCTAssertEqual(initial.batchSize, 1)
    XCTAssertEqual(medium.batchSize, 2)
    XCTAssertEqual(fast.batchSize, 3)
    XCTAssertEqual(fastest.batchSize, 4)
    XCTAssertGreaterThanOrEqual(initial.interval, fastest.interval)
  }

  func testLayoutClassUsesContainerWidthInsteadOfDeviceOrientation() {
    XCTAssertEqual(KeyboardLayoutClass.classify(width: 390, isPad: false), .compactPhone)
    XCTAssertEqual(KeyboardLayoutClass.classify(width: 844, isPad: false), .widePhone)
    XCTAssertEqual(KeyboardLayoutClass.classify(width: 650, isPad: true), .widePhone)
    XCTAssertEqual(KeyboardLayoutClass.classify(width: 820, isPad: true), .regularPad)
    XCTAssertEqual(KeyboardLayoutClass.classify(width: 1_100, isPad: true), .widePad)
  }
}
