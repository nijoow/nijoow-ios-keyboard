//
//  HangulAutomata.swift
//  njjoow-keyboard
//
//  Created by 이우진 on 4/8/26.
//

import Foundation

// MARK: - 한글 자모 정의

/// 초성 목록 (19개)
private let CHOSEONG: [Character] = [
  "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
  "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
]

/// 중성 목록 (21개)
private let JUNGSEONG: [Character] = [
  "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ",
  "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ",
  "ㅡ", "ㅢ", "ㅣ"
]

/// 종성 목록 (28개, 0번은 빈 종성)
private let JONGSEONG: [Character] = [
  "\0", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ",
  "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ",
  "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
]

// MARK: - 인덱스 헬퍼

private func choseongIndex(_ ch: Character) -> Int? {
  CHOSEONG.firstIndex(of: ch)
}

private func jungseongIndex(_ ch: Character) -> Int? {
  JUNGSEONG.firstIndex(of: ch)
}

private func jongseongIndex(_ ch: Character) -> Int? {
  JONGSEONG.firstIndex(of: ch)
}

// MARK: - 복합 중성 조합 테이블

/// (중성A, 중성B) -> 복합 중성
private let COMPOUND_JUNGSEONG: [Character: [Character: Character]] = [
  "ㅗ": ["ㅏ": "ㅘ", "ㅐ": "ㅙ", "ㅣ": "ㅚ"],
  "ㅜ": ["ㅓ": "ㅝ", "ㅔ": "ㅞ", "ㅣ": "ㅟ"],
  "ㅡ": ["ㅣ": "ㅢ"]
]

/// 복합 중성 -> (중성A, 중성B) 분해
private let DECOMPOSE_JUNGSEONG: [Character: (Character, Character)] = [
  "ㅘ": ("ㅗ", "ㅏ"), "ㅙ": ("ㅗ", "ㅐ"), "ㅚ": ("ㅗ", "ㅣ"),
  "ㅝ": ("ㅜ", "ㅓ"), "ㅞ": ("ㅜ", "ㅔ"), "ㅟ": ("ㅜ", "ㅣ"),
  "ㅢ": ("ㅡ", "ㅣ")
]

// MARK: - 복합 종성 조합 테이블

/// (종성A, 종성B) -> 복합 종성
private let COMPOUND_JONGSEONG: [Character: [Character: Character]] = [
  "ㄱ": ["ㅅ": "ㄳ"],
  "ㄴ": ["ㅈ": "ㄵ", "ㅎ": "ㄶ"],
  "ㄹ": ["ㄱ": "ㄺ", "ㅁ": "ㄻ", "ㅂ": "ㄼ", "ㅅ": "ㄽ", "ㅌ": "ㄾ", "ㅍ": "ㄿ", "ㅎ": "ㅀ"],
  "ㅂ": ["ㅅ": "ㅄ"]
]

/// 복합 종성 -> (종성A, 종성B) 분해
private let DECOMPOSE_JONGSEONG: [Character: (Character, Character)] = [
  "ㄳ": ("ㄱ", "ㅅ"), "ㄵ": ("ㄴ", "ㅈ"), "ㄶ": ("ㄴ", "ㅎ"),
  "ㄺ": ("ㄹ", "ㄱ"), "ㄻ": ("ㄹ", "ㅁ"), "ㄼ": ("ㄹ", "ㅂ"),
  "ㄽ": ("ㄹ", "ㅅ"), "ㄾ": ("ㄹ", "ㅌ"), "ㄿ": ("ㄹ", "ㅍ"),
  "ㅀ": ("ㄹ", "ㅎ"), "ㅄ": ("ㅂ", "ㅅ")
]

// MARK: - 자모 분류

func isValidChoseong(_ ch: Character) -> Bool {
  CHOSEONG.contains(ch)
}

func isValidJungseong(_ ch: Character) -> Bool {
  JUNGSEONG.contains(ch)
}

func isValidJongseong(_ ch: Character) -> Bool {
  JONGSEONG.dropFirst().contains(ch)
}

// MARK: - 음절 조합 / 분해

/// 초성+중성+종성 -> 완성형 음절
func composeSyllable(_ cho: Character, _ jung: Character, _ jong: Character) -> Character? {
  guard let ci = choseongIndex(cho),
        let ji = jungseongIndex(jung),
        let joi = jongseongIndex(jong) else { return nil }
  let value = 0xAC00 + (ci * 21 + ji) * 28 + joi;
  guard let scalar = Unicode.Scalar(value) else { return nil }
  return Character(scalar)
}

// MARK: - HangulAutomata

/// 한글 입력 오토마타 상태
enum HangulState {
  case empty
  case cho(Character)
  case choJung(Character, Character)
  case choJungJong(Character, Character, Character)
}

class HangulAutomata {

  private var state: HangulState = .empty

  /// 현재 조합 중인 음절 (문자열, 없으면 nil)
  var currentChar: Character? {
    switch state {
    case .empty:
      return nil
    case .cho(let cho):
      return cho
    case .choJung(let cho, let jung):
      return composeSyllable(cho, jung, "\0") ?? jung
    case .choJungJong(let cho, let jung, let jong):
      return composeSyllable(cho, jung, jong) ?? jong
    }
  }

  /// 오토마타 초기화
  func reset() {
    state = .empty;
  }

  // MARK: - 입력 처리

  /// 자모 입력. 반환: (확정 문자열, 새로운 조합중 음절)
  func input(_ jamo: Character) -> (commit: String, current: Character?) {
    if isValidJungseong(jamo) {
      return inputJungseong(jamo);
    } else if isValidChoseong(jamo) || isValidJongseong(jamo) {
      return inputJaeum(jamo);
    } else {
      let committed = flushAll();
      return (committed + String(jamo), nil);
    }
  }

  /// 백스페이스 처리. 반환: (삭제할 문자 수, 새로 삽입할 문자열)
  func backspace() -> (deleteCount: Int, insert: String) {
    switch state {
    case .empty:
      return (1, "")

    case .cho:
      state = .empty;
      return (1, "")

    case .choJung(let cho, let jung):
      if let (j1, _) = DECOMPOSE_JUNGSEONG[jung] {
        state = .choJung(cho, j1);
        let newSyl = composeSyllable(cho, j1, "\0") ?? j1;
        return (1, String(newSyl))
      } else {
        state = .cho(cho);
        return (1, String(cho))
      }

    case .choJungJong(let cho, let jung, let jong):
      if let (j1, _) = DECOMPOSE_JONGSEONG[jong] {
        state = .choJungJong(cho, jung, j1);
        let newSyl = composeSyllable(cho, jung, j1) ?? j1;
        return (1, String(newSyl))
      } else {
        state = .choJung(cho, jung);
        let newSyl = composeSyllable(cho, jung, "\0") ?? jung;
        return (1, String(newSyl))
      }
    }
  }

  /// 현재 조합 중인 음절을 확정하고 상태 초기화. 반환: 확정된 문자열
  func flush() -> String {
    let result = flushAll();
    state = .empty;
    return result
  }

  /// 특정 자모로 현재 조합 상태를 교체하거나 삽입합니다.
  func insert(char: Character) -> (deleteCount: Int, insert: String) {
    // 현재 조합 중인 상태에서 마지막 요소를 제거하고 새 자모를 입력하여 교체 효과를 냅니다.
    // KeyboardViewController에서 composingChar를 이미 삭제하므로 내부 상태만 조정하고 추가 삭제가 필요한 경우만 deleteCount를 반환합니다.
    _ = backspace()
    let res = input(char)
    
    // 이미 VC에서 composingChar를 지웠으므로 추가 삭제는 0으로 반환합니다.
    return (0, res.commit + (res.current.map { String($0) } ?? ""))
  }

  // MARK: - Private

  private func flushAll() -> String {
    guard let ch = currentChar else {
      state = .empty;
      return ""
    }
    state = .empty;
    return String(ch)
  }

  private func inputJaeum(_ jaeum: Character) -> (commit: String, current: Character?) {
    switch state {
    case .empty:
      state = .cho(jaeum);
      return ("", jaeum)

    case .cho(let prevCho):
      state = .cho(jaeum);
      return (String(prevCho), jaeum)

    case .choJung(let cho, let jung):
      state = .choJungJong(cho, jung, jaeum);
      let syl = composeSyllable(cho, jung, jaeum) ?? jaeum;
      return ("", syl)

    case .choJungJong(let cho, let jung, let jong):
      if let compoundTable = COMPOUND_JONGSEONG[jong],
         let compound = compoundTable[jaeum] {
        state = .choJungJong(cho, jung, compound);
        let syl = composeSyllable(cho, jung, compound) ?? compound;
        return ("", syl)
      } else {
        let prevSyl = composeSyllable(cho, jung, jong) ?? jong;
        state = .cho(jaeum);
        return (String(prevSyl), jaeum)
      }
    }
  }

  private func inputJungseong(_ moeum: Character) -> (commit: String, current: Character?) {
    switch state {
    case .empty:
      // 단독 모음 삽입
      state = .empty;
      return (String(moeum), nil)

    case .cho(let cho):
      state = .choJung(cho, moeum);
      let syl = composeSyllable(cho, moeum, "\0") ?? moeum;
      return ("", syl)

    case .choJung(let cho, let jung):
      if let compoundTable = COMPOUND_JUNGSEONG[jung],
         let compound = compoundTable[moeum] {
        state = .choJung(cho, compound);
        let syl = composeSyllable(cho, compound, "\0") ?? compound;
        return ("", syl)
      } else {
        let prevSyl = composeSyllable(cho, jung, "\0") ?? jung;
        state = .empty;
        return (String(prevSyl) + String(moeum), nil)
      }

    case .choJungJong(let cho, let jung, let jong):
      if let (j1, j2) = DECOMPOSE_JONGSEONG[jong] {
        let prevSyl = composeSyllable(cho, jung, j1) ?? j1;
        state = .choJung(j2, moeum);
        let newSyl = composeSyllable(j2, moeum, "\0") ?? moeum;
        return (String(prevSyl), newSyl)
      } else {
        let prevSyl = composeSyllable(cho, jung, "\0") ?? jung;
        state = .choJung(jong, moeum);
        let newSyl = composeSyllable(jong, moeum, "\0") ?? moeum;
        return (String(prevSyl), newSyl)
      }
    }
  }
}
