import UIKit

enum KeyboardInputLayout: Equatable {
  case text
  case number
  case decimal
  case phone

  init(keyboardType: UIKeyboardType) {
    switch keyboardType {
    case .numberPad, .asciiCapableNumberPad: self = .number
    case .decimalPad: self = .decimal
    case .phonePad: self = .phone
    default: self = .text
    }
  }

  var isNumeric: Bool { self != .text }

  func rows(decimalSeparator: String, showsSymbols: Bool = false) -> [[String]] {
    let last: [String]
    switch self {
    case .decimal: last = [decimalSeparator, "0", "backspace"]
    case .phone: last = ["+", "0", "backspace"]
    default: last = ["symbol", "0", "backspace"]
    }
    if self == .number && showsSymbols {
      return [["*", "#", "+"], ["-", "/", "."], ["(", ")", ","], last]
    }
    return [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], last]
  }
}
