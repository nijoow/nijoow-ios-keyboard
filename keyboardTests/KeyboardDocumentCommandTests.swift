import XCTest

@MainActor
final class KeyboardDocumentCommandTests: XCTestCase {
  func testDocumentCommandsPreserveOrder() {
    let document = InMemoryKeyboardDocument(text: "ab")

    KeyboardDocumentCommandExecutor.execute(.insert("c"), on: document)
    KeyboardDocumentCommandExecutor.execute(.deleteBackward, on: document)
    KeyboardDocumentCommandExecutor.execute(.insert("d"), on: document)

    XCTAssertEqual(document.text, "abd")
    XCTAssertEqual(document.commands, [.insert("c"), .deleteBackward, .insert("d")])
  }

  func testRepeatedDeleteContinuesAcrossParagraphBoundary() {
    let document = InMemoryKeyboardDocument(text: "첫 문단\n둘째")

    for _ in 0..<3 {
      KeyboardDocumentCommandExecutor.execute(.deleteBackward, on: document)
    }

    XCTAssertEqual(document.text, "첫 문단")
  }

  func testEmptyInsertAndZeroCursorMoveAreIgnored() {
    let document = InMemoryKeyboardDocument(text: "text")

    XCTAssertFalse(KeyboardDocumentCommandExecutor.execute(.insert(""), on: document))
    XCTAssertFalse(KeyboardDocumentCommandExecutor.execute(.moveCursor(0), on: document))
    XCTAssertTrue(document.commands.isEmpty)
  }
}

@MainActor
private final class InMemoryKeyboardDocument: KeyboardDocumentEditing {
  var text: String
  private(set) var commands: [KeyboardDocumentCommand] = []

  init(text: String) {
    self.text = text
  }

  func insertDocumentText(_ text: String) {
    commands.append(.insert(text))
    self.text.append(text)
  }

  func deleteDocumentBackward() {
    commands.append(.deleteBackward)
    if !text.isEmpty { text.removeLast() }
  }

  func moveDocumentCursor(by offset: Int) {
    commands.append(.moveCursor(offset))
  }
}
