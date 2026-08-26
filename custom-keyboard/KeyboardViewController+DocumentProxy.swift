import UIKit

extension KeyboardViewController {
  func insertTextThroughProxy(_ text: String) {
    guard !text.isEmpty else { return }
    KeyboardInputDiagnostics.shared.recordInsertRequest(characterCount: text.count)
    textDocumentProxy.insertText(text)
  }

  func deleteBackwardThroughProxy() {
    KeyboardInputDiagnostics.shared.recordDeleteRequest()
    textDocumentProxy.deleteBackward()
  }

  func moveCursorThroughProxy(byCharacterOffset offset: Int) {
    guard offset != 0 else { return }
    KeyboardInputDiagnostics.shared.recordCursorMoveRequest()
    textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
  }
}
