//
//  HangulAutomata.swift
//  custom-keyboard
//
//  Created by 이우진 on 4/8/26.
//

import Foundation

// MARK: - 한글 자모 정의

private let CHOSEONG: [Character] = [
  "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
  "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
];

private let JUNGSEONG: [Character] = [
  "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ",
  "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ",
  "ㅡ", "ㅢ", "ㅣ"
];

private let JONGSEONG: [Character] = [
  "\0", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ",
  "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ",
  "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"
];

private let COMPOUND_JUNGSEONG: [Character: [Character: Character]] = [
  "ㅗ": ["ㅏ": "ㅘ", "ㅐ": "ㅙ", "ㅣ": "ㅚ"],
  "ㅜ": ["ㅓ": "ㅝ", "ㅔ": "ㅞ", "ㅣ": "ㅟ"],
  "ㅡ": ["ㅣ": "ㅢ"]
];

private let COMPOUND_JONGSEONG: [Character: [Character: Character]] = [
  "ㄱ": ["ㅅ": "ㄳ"],
  "ㄴ": ["ㅈ": "ㄵ", "ㅎ": "ㄶ"],
  "ㄹ": ["ㄱ": "ㄺ", "ㅁ": "ㄻ", "ㅂ": "ㄼ", "ㅅ": "ㄽ", "ㅌ": "ㄾ", "ㅍ": "ㄿ", "ㅎ": "ㅀ"],
  "ㅂ": ["ㅅ": "ㅄ"]
];

// MARK: - HangulAutomata

class HangulAutomata {
  
  /// 사용자가 입력한 순수 자모 스택
  private(set) var jamoStack: [Character] = [];
  
  /// 오토마타 초기화
  func reset() {
    jamoStack.removeAll();
  }
  
  /// 자모 입력
  func input(_ jamo: Character) {
    jamoStack.append(jamo);
  }
  
  /// 백스페이스 (스택 제거)
  func backspace() {
    if !jamoStack.isEmpty {
      jamoStack.removeLast();
    }
  }
  
  /// 현재 스택을 한글 음절로 조합하여 문자열 반환
  func compose() -> String {
    guard !jamoStack.isEmpty else { return ""; }
    
    var result = "";
    var currentCho: Character? = nil;
    var currentJung: Character? = nil;
    var currentJong: Character? = nil;
    
    for jamo in jamoStack {
      if isJungseong(jamo) {
        // 1. 모음인 경우
        if let _ = currentCho, currentJung == nil {
          // 초성만 있을 때 -> 합쳐서 초중 조합 시작
          currentJung = jamo;
        } else if let cho = currentCho, let jung = currentJung, currentJong == nil {
          // 초성+중성이 있을 때 -> 복합 중성 도전
          if let compound = COMPOUND_JUNGSEONG[jung]?[jamo] {
            currentJung = compound;
          } else {
            // 복합 중성 안되면 현재꺼 쏘고 새로운 모음 시작 (단독 모음)
            result += commitSyllable(cho, jung, nil);
            currentCho = nil; currentJung = nil;
            result += String(jamo);
          }
        } else if let cho = currentCho, let jung = currentJung, let jong = currentJong {
          // 종성까지 다 있을 때 -> 종성 하나를 초성으로 떼주고 새로운 음절 시작 (도깨비 현상)
          if let (j1, j2) = decomposeJongseong(jong) {
            result += commitSyllable(cho, jung, j1);
            currentCho = j2;
            currentJung = jamo;
            currentJong = nil;
          } else {
            result += commitSyllable(cho, jung, nil);
            currentCho = jong;
            currentJung = jamo;
            currentJong = nil;
          }
        } else if currentCho == nil {
          // 초성 없이 들어온 모음 (단독)
          if let jung = currentJung, let compound = COMPOUND_JUNGSEONG[jung]?[jamo] {
            currentJung = compound;
          } else {
            if let jung = currentJung { result += String(jung); }
            currentJung = jamo;
          }
        }
      } else {
        // 2. 자음인 경우
        if currentCho == nil && currentJung == nil {
          // 아예 처음 -> 초성 시작
          currentCho = jamo;
        } else if let _ = currentCho, currentJung == nil {
          // 초성만 있는데 또 자음 -> 이전 초성 쏘고 새로 초성 시작
          result += String(currentCho!);
          currentCho = jamo;
        } else if let cho = currentCho, let jung = currentJung, currentJong == nil {
          // 초중 있는데 자음 -> 종성 도전
          if isJongseong(jamo) {
            currentJong = jamo;
          } else {
            // 종성 안되는 자음 -> 이전꺼 쏘고 새로 초성 시작
            result += commitSyllable(cho, jung, nil);
            currentCho = jamo; currentJung = nil;
          }
        } else if let cho = currentCho, let jung = currentJung, let jong = currentJong {
          // 이미 종성 있는데 자음 -> 복합 종성 도전
          if let compound = COMPOUND_JONGSEONG[jong]?[jamo] {
            currentJong = compound;
          } else {
            // 안되면 현재 음절 쏘고 새로 시작
            result += commitSyllable(cho, jung, jong);
            currentCho = jamo; currentJung = nil; currentJong = nil;
          }
        } else if currentCho == nil, let jung = currentJung {
          // 초성 없이 모음만 있다 자음 -> 모음 쏘고 초성 시작
          result += String(jung);
          currentJung = nil;
          currentCho = jamo;
        }
      }
    }
    
    // 남은 미완성 조각들 합치기
    if let cho = currentCho {
      result += commitSyllable(cho, currentJung, currentJong);
    } else if let jung = currentJung {
      result += String(jung);
    }
    
    return result;
  }
  
  // MARK: - Private 헬퍼
  
  private func isJungseong(_ ch: Character) -> Bool {
    return JUNGSEONG.contains(ch);
  }
  
  private func isJongseong(_ ch: Character) -> Bool {
    return JONGSEONG.contains(ch) && ch != "\0";
  }
  
  private func decomposeJongseong(_ jong: Character) -> (Character, Character)? {
    for (first, dict) in COMPOUND_JONGSEONG {
      for (second, compound) in dict {
        if compound == jong { return (first, second); }
      }
    }
    return nil;
  }
  
  private func commitSyllable(_ cho: Character, _ jung: Character?, _ jong: Character?) -> String {
    guard let jung = jung else { return String(cho); }
    
    let choIdx = CHOSEONG.firstIndex(of: cho) ?? 0;
    let jungIdx = JUNGSEONG.firstIndex(of: jung) ?? 0;
    let jongIdx = JONGSEONG.firstIndex(of: jong ?? "\0") ?? 0;
    
    let unicode = 0xAC00 + (choIdx * 21 + jungIdx) * 28 + jongIdx;
    if let scalar = Unicode.Scalar(unicode) {
      return String(Character(scalar));
    }
    return String(cho) + String(jung) + (jong.map { String($0) } ?? "");
  }
}
