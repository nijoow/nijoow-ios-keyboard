import Foundation

class HangulAutomata {
    // Unicode Constants
    private let HANGUL_BASE: Int = 0xAC00
    private let CHO_BASE: Int = 0x1100
    private let JUNG_BASE: Int = 0x1161
    private let JONG_BASE: Int = 0x11A7
    
    // Jamo Lists
    private let choList = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
    private let jungList = ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"]
    private let jongList = ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]

    // State
    enum State {
        case empty
        case cho
        case jung
        case jong
    }
    
    private var currentState: State = .empty
    private var choIdx: Int = -1
    private var jungIdx: Int = -1
    private var jongIdx: Int = 0
    
    // For handling double vowels/consonants
    private var lastJungIdx: Int = -1
    private var lastJongIdx: Int = -1

    func insert(_ jamo: String) -> (text: String, deleteCount: Int) {
        if choList.contains(jamo) {
            return handleConsonant(jamo)
        } else if jungList.contains(jamo) {
            return handleVowel(jamo)
        }
        return (jamo, 0)
    }

    private func handleConsonant(_ jamo: String) -> (String, Int) {
        let idx = choList.firstIndex(of: jamo) ?? -1
        
        switch currentState {
        case .empty:
            choIdx = idx
            currentState = .cho
            return (jamo, 0)
            
        case .cho:
            // Previous was a consonant, if current is also consonant, commit previous and start new
            choIdx = idx
            return (jamo, 0)
            
        case .jung:
            // Previous was CHOSEONG + JUNGSEONG, current is CONSONANT -> could be JONGSEONG
            let jongIndex = jongList.firstIndex(of: jamo) ?? 0
            if jongIndex > 0 {
                jongIdx = jongIndex
                currentState = .jong
                return (compose(), 1)
            } else {
                // Not a valid JONGSEONG (e.g. ㄸ, ㅃ, ㅉ)
                reset()
                choIdx = idx
                currentState = .cho
                return (jamo, 0)
            }
            
        case .jong:
            // Previous was CHOSEONG + JUNGSEONG + JONGSEONG
            // Check if current consonant can combine with previous JONGSEONG
            if let combinedIdx = combineJong(first: jongIdx, second: jamo) {
                jongIdx = combinedIdx
                return (compose(), 1)
            } else {
                // Cannot combine, commit current and start new CHO
                reset()
                choIdx = idx
                currentState = .cho
                return (jamo, 0)
            }
        }
    }

    private func handleVowel(_ jamo: String) -> (String, Int) {
        let idx = jungList.firstIndex(of: jamo) ?? -1
        
        switch currentState {
        case .empty:
            currentState = .jung
            jungIdx = idx
            return (jamo, 0)
            
        case .cho:
            // CHOSEONG + VOWEL = Syllable
            jungIdx = idx
            currentState = .jung
            return (compose(), 1)
            
        case .jung:
            // VOWEL + VOWEL -> check combination
            if let combinedIdx = combineJung(first: jungIdx, second: jamo) {
                jungIdx = combinedIdx
                return (composeJungOnly(), 1)
            } else {
                reset()
                jungIdx = idx
                currentState = .jung
                return (jamo, 0)
            }
            
        case .jong:
            // CHOSEONG + JUNGSEONG + JONGSEONG + VOWEL
            // JONGSEONG must move to next syllable as CHOSEONG
            let prevJamo = jongList[jongIdx]
            let (newCho, remains) = splitJong(jongIdx)
            
            if remains > 0 {
                // Composite JONGSEONG (e.g., ㄳ -> ㄱ goes to prev, ㅅ goes to next)
                jongIdx = remains
                let firstPart = compose()
                
                reset()
                choIdx = choList.firstIndex(of: newCho) ?? -1
                jungIdx = idx
                currentState = .jung
                return (firstPart + compose(), 2)
            } else {
                // Single JONGSEONG (e.g., ㄱ -> ㄱ goes to next)
                let firstPart = composeWithoutJong()
                reset()
                choIdx = choList.firstIndex(of: prevJamo) ?? -1
                jungIdx = idx
                currentState = .jung
                return (firstPart + compose(), 2)
            }
        }
    }
    
    func delete() -> (text: String, deleteCount: Int) {
        switch currentState {
        case .empty:
            return ("", 0)
        case .cho:
            reset()
            return ("", 1)
        case .jung:
            if choIdx != -1 {
                // Was syllable, now only Cho
                currentState = .cho
                jungIdx = -1
                return (choList[choIdx], 1)
            } else {
                reset()
                return ("", 1)
            }
        case .jong:
            let (_, remains) = splitJong(jongIdx)
            if remains > 0 {
                // Was composite Jong, now single Jong
                jongIdx = remains
                return (compose(), 1)
            } else {
                // Was single Jong, now only Cho + Jung
                jongIdx = 0
                currentState = .jung
                return (compose(), 1)
            }
        }
    }

    private func compose() -> String {
        if choIdx != -1 && jungIdx != -1 {
            let code = HANGUL_BASE + (choIdx * 588) + (jungIdx * 28) + jongIdx
            if let scalar = UnicodeScalar(code) {
                return String(Character(scalar))
            }
        }
        return ""
    }
    
    private func composeWithoutJong() -> String {
        let code = HANGUL_BASE + (choIdx * 588) + (jungIdx * 28)
        if let scalar = UnicodeScalar(code) {
            return String(Character(scalar))
        }
        return ""
    }
    
    private func composeJungOnly() -> String {
        return jungList[jungIdx]
    }

    private func reset() {
        currentState = .empty
        choIdx = -1
        jungIdx = -1
        jongIdx = 0
    }

    // Helper: Combine vowels (ㅗ + ㅏ = ㅘ, etc.)
    private func combineJung(first: Int, second: String) -> Int? {
        let f = jungList[first]
        if f == "ㅗ" && second == "ㅏ" { return jungList.firstIndex(of: "ㅘ") }
        if f == "ㅗ" && second == "ㅐ" { return jungList.firstIndex(of: "ㅙ") }
        if f == "ㅗ" && second == "ㅣ" { return jungList.firstIndex(of: "ㅚ") }
        if f == "ㅜ" && second == "ㅓ" { return jungList.firstIndex(of: "ㅝ") }
        if f == "ㅜ" && second == "ㅔ" { return jungList.firstIndex(of: "ㅞ") }
        if f == "ㅜ" && second == "ㅣ" { return jungList.firstIndex(of: "ㅟ") }
        if f == "ㅡ" && second == "ㅣ" { return jungList.firstIndex(of: "ㅢ") }
        return nil
    }

    // Helper: Combine final consonants (ㄱ + ㅅ = ㄳ, etc.)
    private func combineJong(first: Int, second: String) -> Int? {
        let f = jongList[first]
        if f == "ㄱ" && second == "ㅅ" { return jongList.firstIndex(of: "ㄳ") }
        if f == "ㄴ" && second == "ㅈ" { return jongList.firstIndex(of: "ㄵ") }
        if f == "ㄴ" && second == "ㅎ" { return jongList.firstIndex(of: "ㄶ") }
        if f == "ㄹ" && second == "ㄱ" { return jongList.firstIndex(of: "ㄺ") }
        if f == "ㄹ" && second == "ㅁ" { return jongList.firstIndex(of: "ㄻ") }
        if f == "ㄹ" && second == "ㅂ" { return jongList.firstIndex(of: "ㄼ") }
        if f == "ㄹ" && second == "ㅅ" { return jongList.firstIndex(of: "ㄽ") }
        if f == "ㄹ" && second == "ㅌ" { return jongList.firstIndex(of: "ㄾ") }
        if f == "ㄹ" && second == "ㅍ" { return jongList.firstIndex(of: "ㄿ") }
        if f == "ㄹ" && second == "ㅎ" { return jongList.firstIndex(of: "ㅀ") }
        if f == "ㅂ" && second == "ㅅ" { return jongList.firstIndex(of: "ㅄ") }
        return nil
    }

    // Helper: Split composite Jong (ㄳ -> ㅅ, remains ㄱ)
    private func splitJong(_ idx: Int) -> (newCho: String, remains: Int) {
        let j = jongList[idx]
        switch j {
        case "ㄳ": return ("ㅅ", jongList.firstIndex(of: "ㄱ")!)
        case "ㄵ": return ("ㅈ", jongList.firstIndex(of: "ㄴ")!)
        case "ㄶ": return ("ㅎ", jongList.firstIndex(of: "ㄴ")!)
        case "ㄺ": return ("ㄱ", jongList.firstIndex(of: "ㄹ")!)
        case "ㄻ": return ("ㅁ", jongList.firstIndex(of: "ㄹ")!)
        case "ㄼ": return ("ㅂ", jongList.firstIndex(of: "ㄹ")!)
        case "ㄽ": return ("ㅅ", jongList.firstIndex(of: "ㄹ")!)
        case "ㄾ": return ("ㅌ", jongList.firstIndex(of: "ㄹ")!)
        case "ㄿ": return ("ㅍ", jongList.firstIndex(of: "ㄹ")!)
        case "ㅀ": return ("ㅎ", jongList.firstIndex(of: "ㄹ")!)
        case "ㅄ": return ("ㅅ", jongList.firstIndex(of: "ㅂ")!)
        default: return ("", 0)
        }
    }
}
