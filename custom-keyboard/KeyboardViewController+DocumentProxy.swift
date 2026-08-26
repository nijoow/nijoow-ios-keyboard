import UIKit

extension KeyboardViewController {
  func insertTextThroughProxy(_ text: String) {
    guard !text.isEmpty else { return }
    KeyboardInputDiagnostics.shared.recordInsertRequest(characterCount: text.count)
    KeyboardDocumentCommandExecutor.execute(.insert(text), on: self)
  }

  func deleteBackwardThroughProxy() {
    KeyboardInputDiagnostics.shared.recordDeleteRequest()
    KeyboardDocumentCommandExecutor.execute(.deleteBackward, on: self)
  }

  func moveCursorThroughProxy(byCharacterOffset offset: Int) {
    guard offset != 0 else { return }
    KeyboardInputDiagnostics.shared.recordCursorMoveRequest()
    KeyboardDocumentCommandExecutor.execute(.moveCursor(offset), on: self)
  }
}

extension KeyboardViewController: KeyboardDocumentEditing {
  func insertDocumentText(_ text: String) {
    textDocumentProxy.insertText(text)
  }

  func deleteDocumentBackward() {
    textDocumentProxy.deleteBackward()
  }

  func moveDocumentCursor(by offset: Int) {
    textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
  }
}
