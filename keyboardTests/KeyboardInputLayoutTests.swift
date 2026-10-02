import UIKit
import XCTest

@MainActor
final class KeyboardInputLayoutTests: XCTestCase {
  func testNumericTraitsSelectDedicatedPadAndTextFieldRestoresLetters() {
    XCTAssertEqual(KeyboardInputLayout(keyboardType: .numberPad), .number)
    XCTAssertEqual(KeyboardInputLayout(keyboardType: .asciiCapableNumberPad), .number)
    XCTAssertEqual(KeyboardInputLayout(keyboardType: .decimalPad), .decimal)
    XCTAssertEqual(KeyboardInputLayout(keyboardType: .phonePad), .phone)
    for type in [UIKeyboardType.default, .emailAddress, .URL, .namePhonePad, .numbersAndPunctuation] {
      XCTAssertEqual(KeyboardInputLayout(keyboardType: type), .text)
    }
  }

  func testDecimalPadUsesLocaleSeparatorAndIntegerPadDoesNotOfferDecimal() {
    XCTAssertEqual(KeyboardInputLayout.decimal.rows(decimalSeparator: ",").last,
                   [",", "0", "backspace"])
    let integerKeys = KeyboardInputLayout.number.rows(decimalSeparator: ".").flatMap { $0 }
    XCTAssertFalse(integerKeys.contains("."))
    XCTAssertEqual(integerKeys.filter { Int($0) != nil }.count, 10)
    XCTAssertTrue(integerKeys.contains("backspace"))
    XCTAssertEqual(KeyboardInputLayout.number.rows(decimalSeparator: ".").last,
                   [KeyboardConstants.KeyID.symbol, "0", "backspace"])
  }

  func testNumericSymbolsKeepThreeColumnsAndPreserveSpecializedPads() {
    let rows = KeyboardInputLayout.number.rows(decimalSeparator: ".", showsSymbols: true)
    XCTAssertEqual(rows.count, 4)
    XCTAssertTrue(rows.allSatisfy { $0.count == 3 })
    XCTAssertEqual(Set(rows.prefix(3).flatMap { $0 }), Set(["*", "#", "+", "-", "/", ".", "(", ")", ","]))
    for layout in [KeyboardInputLayout.decimal, .phone] {
      XCTAssertEqual(layout.rows(decimalSeparator: ",", showsSymbols: true),
                     layout.rows(decimalSeparator: ","))
    }
  }
}
