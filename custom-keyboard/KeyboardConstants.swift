import UIKit

struct KeyboardConstants {
  // MARK: - 한글 맵핑
  static let HANGUL_MAP: [Character: Character] = [
    "q": "ㅂ", "w": "ㅈ", "e": "ㄷ", "r": "ㄱ", "t": "ㅅ",
    "y": "ㅛ", "u": "ㅕ", "i": "ㅑ", "o": "ㅐ", "p": "ㅔ",
    "a": "ㅁ", "s": "ㄴ", "d": "ㅇ", "f": "ㄹ", "g": "ㅎ",
    "h": "ㅗ", "j": "ㅓ", "k": "ㅏ", "l": "ㅣ",
    "z": "ㅋ", "x": "ㅌ", "c": "ㅊ", "v": "ㅍ", "b": "ㅠ",
    "n": "ㅜ", "m": "ㅡ"
  ]

  static let HANGUL_SHIFT_MAP: [Character: Character] = [
    "q": "ㅃ", "w": "ㅉ", "e": "ㄸ", "r": "ㄲ", "t": "ㅆ",
    "o": "ㅒ", "p": "ㅖ"
  ]

  // MARK: - 기호 맵핑
  static let SYM_ROW1_NORMAL: [String]  = ["(", ")", "[", "]", "{", "}", "<", ">", "\"", "'"]
  static let SYM_ROW2_NORMAL: [String]  = ["@",  "+", "-", "*", "×", "÷",  "^",":", ";"]
  static let SYM_ROW3_NORMAL: [String]  = ["~","_","#" ,"," , "?", "!","/"]

  static let SYM_ROW1_SHIFTED: [String] = ["₩", "$", "=", "≠", "≤", "≥", "&", "|", "\\", "°"]
  static let SYM_ROW2_SHIFTED: [String] = ["○", "●", "□", "■", "←", "↑", "↓", "→", "↔" ]
  static let SYM_ROW3_SHIFTED: [String] = ["♡", "♥", "☆", "★", "%", "·", "✓"]

  // MARK: - 이모지 데이터
  static let COMMON_EMOJIS: [String] = [
    "😀", "😂", "🥹", "😍", "🥰", "😊", "😎", "🤔",
    "😅", "😭", "😱", "🤯", "🥺", "😏", "😒", "😡",
    "👍", "👎", "👏", "🙏", "🤝", "✌️", "💪", "🤞",
    "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "💔",
    "🔥", "⭐", "🌟", "✨", "💥", "🎉", "🎊", "🌈",
    "🍎", "🍕", "🍔", "🍜", "🍣", "☕", "🍰", "🍫",
    "🐶", "🐱", "🐰", "🐻", "🐼", "🐨", "🦊", "🐯",
    "⚽", "🏀", "🎮", "🎲", "🚀", "✈️", "🚗", "💻",
    "😆", "🤣", "🙂", "🙃", "😉", "😇", "🥳", "🤩",
    "👋", "🤚", "🖐", "✋", "🤙", "👌", "🤌", "☝",
    "💕", "💞", "💓", "💗", "💖", "💘", "💝", "❣️",
    "🌸", "🌺", "🌹", "🌻", "🌼", "🍀", "🌿", "🌊"
  ]

  // MARK: - 레이아웃 수치
  static let UTIL_ROW_H: CGFloat = 34
  static let KEY_FONT_SIZE: CGFloat = 20
  static let NUMBER_ROW_H: CGFloat = 38
  static let MAIN_KEY_H: CGFloat = 42
  static let BOTTOM_ROW_H: CGFloat = 38
  static let CORNER_RADIUS: CGFloat = 12
  
  // 전체 높이 고정용 (여백 포함, 안전 영역 제외)
  // 상단(6) + 유틸(34) + 간격(7) + 메인(179) + 간격(7) + 바닥(38) + 패딩(6) = 277
  static let TOTAL_CONTENT_H: CGFloat = 277
}
