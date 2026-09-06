import UIKit

struct KeyboardConstants {
  enum KeyID {
    static let dummy = "dummy"
    static let shift = "shift"
    static let backspace = "backspace"
    static let language = "lang"
    static let symbol = "symbol"
    static let enter = "enter"
    static let custom = "custom"
    static let dismiss = "dismiss"
    static let nextKeyboard = "next_keyboard"
    static let space = " "
    static let cursorLineStart = "cursor_line_start"
    static let cursorLeft = "cursor_left"
    static let cursorRight = "cursor_right"
    static let cursorLineEnd = "cursor_line_end"

    static let cursorKeys: Set<String> = [
      cursorLineStart, cursorLeft, cursorRight, cursorLineEnd,
    ]

    static let specialKeys: Set<String> = [
      shift, backspace, language, symbol, enter, custom, dismiss, nextKeyboard, space,
    ]
  }

  enum Storage {
    static let hangulMode = "isHangulState"
  }

  enum Interaction {
    static let shiftDoubleTapInterval: TimeInterval = 0.3
    static let shiftLongPressDuration: TimeInterval = 0.5
    static let variantLongPressDuration: TimeInterval = 0.4
    static let spaceLongPressDuration: TimeInterval = 0.3
    static let spaceCursorStep: CGFloat = 12
    /// 지연된 한 번의 pan 이벤트가 문서 프록시 IPC를 무제한 몰아내지 않게 하는 상한.
    /// 처리하지 못한 이동량은 누적값에 남겨 다음 이벤트에서 이어서 처리한다.
    static let maxCursorStepsPerPanEvent = 8
    static let repeatStartDelay: TimeInterval = 0.4
    static let cursorRepeatInterval: TimeInterval = 0.1
    static let backspaceRepeatStartDelay: TimeInterval = 0.25
    static let fastRepeatInterval: TimeInterval = 0.05
    static let fastestRepeatInterval: TimeInterval = 0.03
    static let fastRepeatThreshold = 10
    static let fastestRepeatThreshold = 50
    static let horizontalHitSlop: CGFloat = 8
    /// 행 컨테이너가 끝키로 넘긴 터치를 손가락을 뗄 때까지 유지하는 범위.
    /// 새 터치 대상 선택은 `KeyButton.hitTest`가 실제 bounds로 제한하므로 이 값을 넓혀도
    /// 이웃 키의 새 터치를 가로채지 않는다. 9키 행의 양옆 더미 폭과 화면 끝 여백을 포함한다.
    static let keyTrackingHitSlop: CGFloat = 24
    /// 빠른 탭도 눌림 상태가 최소 한 프레임 이상 보이도록 유지하는 시간.
    /// 입력과 햅틱은 즉시 처리하며 시각 효과 해제에만 적용한다.
    static let minimumPressVisualDuration: TimeInterval = 0.06
    static let sectionHalfSpacing: CGFloat = 3.5
    static let keyboardEdgeSpacing: CGFloat = 6
  }

  // MARK: - 한글 맵핑
  static let hangulMap: [Character: Character] = [
    "q": "ㅂ", "w": "ㅈ", "e": "ㄷ", "r": "ㄱ", "t": "ㅅ",
    "y": "ㅛ", "u": "ㅕ", "i": "ㅑ", "o": "ㅐ", "p": "ㅔ",
    "a": "ㅁ", "s": "ㄴ", "d": "ㅇ", "f": "ㄹ", "g": "ㅎ",
    "h": "ㅗ", "j": "ㅓ", "k": "ㅏ", "l": "ㅣ",
    "z": "ㅋ", "x": "ㅌ", "c": "ㅊ", "v": "ㅍ", "b": "ㅠ",
    "n": "ㅜ", "m": "ㅡ",
  ]

  static let hangulShiftMap: [Character: Character] = [
    "q": "ㅃ", "w": "ㅉ", "e": "ㄸ", "r": "ㄲ", "t": "ㅆ",
    "o": "ㅒ", "p": "ㅖ",
  ]

  // MARK: - 기호 맵핑
  static let symbolRow1: [String] = ["(", ")", "[", "]", "{", "}", "<", ">", "\"", "'"]
  static let symbolRow2: [String] = ["@", "+", "-", "*", "×", "÷", "^", ":", ";"]
  static let symbolRow3: [String] = ["~", "_", "#", ",", "?", "!", "/"]

  static let shiftedSymbolRow1: [String] = ["₩", "$", "=", "≠", "≤", "≥", "&", "|", "\\", "°"]
  static let shiftedSymbolRow2: [String] = ["○", "●", "□", "■", "←", "↑", "↓", "→", "↔"]
  static let shiftedSymbolRow3: [String] = ["♡", "♥", "☆", "★", "%", "·", "✓"]

  // MARK: - 레이아웃 수치
  static let utilityRowHeight: CGFloat = 34
  static let keyFontSize: CGFloat = 20
  static let numberRowHeight: CGFloat = 40
  static let mainKeyHeight: CGFloat = 44
  static let bottomRowHeight: CGFloat = 38
  static let cornerRadius: CGFloat = 12
}
