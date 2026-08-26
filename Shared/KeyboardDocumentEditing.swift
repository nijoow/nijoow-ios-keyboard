import Foundation

enum KeyboardDocumentCommand: Equatable, Sendable {
  case insert(String)
  case deleteBackward
  case moveCursor(Int)
}

@MainActor
protocol KeyboardDocumentEditing: AnyObject {
  func insertDocumentText(_ text: String)
  func deleteDocumentBackward()
  func moveDocumentCursor(by offset: Int)
}

/// UIKit과 분리된 문서 명령 경계. 실제 확장에서는 UITextDocumentProxy로 전달하고,
/// 테스트에서는 메모리 문서로 동일한 명령 순서를 검증한다.
@MainActor
enum KeyboardDocumentCommandExecutor {
  @discardableResult
  static func execute(_ command: KeyboardDocumentCommand, on document: KeyboardDocumentEditing)
    -> Bool
  {
    switch command {
    case .insert(let text):
      guard !text.isEmpty else { return false }
      document.insertDocumentText(text)
    case .deleteBackward:
      document.deleteDocumentBackward()
    case .moveCursor(let offset):
      guard offset != 0 else { return false }
      document.moveDocumentCursor(by: offset)
    }
    return true
  }
}
