import XCTest

@MainActor
final class HangulAutomataTests: XCTestCase {
  func testComposesMultipleSyllables() {
    XCTAssertEqual(compose("ㅎㅏㄴㄱㅡㄹ"), "한글")
  }

  func testMovesFinalConsonantToNextSyllableWhenVowelFollows() {
    XCTAssertEqual(compose("ㄱㅏㄴㅏ"), "가나")
  }

  func testComposesCompoundMedial() {
    XCTAssertEqual(compose("ㄱㅗㅏ"), "과")
  }

  func testKeepsStandaloneVowelStateAfterCommittingPreviousSyllable() {
    XCTAssertEqual(compose("ㄱㅏㅗㅏ"), "가ㅘ")
  }

  func testBackspaceRecomposesFromRemainingJamo() {
    let automata = makeAutomata(from: "ㅎㅏㄴ")

    automata.backspace()

    XCTAssertEqual(automata.compose(), "하")
  }

  private func compose(_ input: String) -> String {
    makeAutomata(from: input).compose()
  }

  private func makeAutomata(from input: String) -> HangulAutomata {
    let automata = HangulAutomata()
    for jamo in input {
      automata.input(jamo)
    }
    return automata
  }
}
