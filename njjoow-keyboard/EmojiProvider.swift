import Foundation

/// [경량화] 최적화된 JSON 구조에 맞춘 이모지 항목 모델
struct EmojiItem: Codable {
    let char: String
    let variations: [EmojiItem]?
}

/// [경량화] subGroups 단계가 제거된 단순화된 그룹 모델
struct EmojiGroup: Codable {
    let groupName: String
    let emojis: [EmojiItem]
}

struct EmojiCategory: Codable {
    let title: String
    let icon: String
    let emojis: [String]
}

class EmojiProvider {
    static let shared = EmojiProvider()
    
    // 기본 카테고리 데이터 (JSON에서 로드된 것)
    private let baseCategories: [EmojiCategory]
    
    // 최근 사용 이모지 목록
    private(set) var recentEmojis: [String] = []
    private let recentKey = "com.njjoow.keyboard.recentEmojis"
    private let maxRecentCount = 40
    
    // UI에 제공할 최종 카테고리 목록 (최근 사용 포함)
    var categories: [EmojiCategory] {
        if recentEmojis.isEmpty {
            return baseCategories
        }
        let recentCategory = EmojiCategory(
            title: "최근 사용",
            icon: "🕒",
            emojis: recentEmojis
        )
        return [recentCategory] + baseCategories
    }
    
    private var emojiToVariations: [String: [String]] = [:]
    
    private init() {
        var loadedCategories: [EmojiCategory] = []
        var variationsMap: [String: [String]] = [:]
        
        // 1. 기본 이모지 데이터 로드
        autoreleasepool {
            if let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                
                let decoder = JSONDecoder()
                if let groups = try? decoder.decode([EmojiGroup].self, from: data) {
                    for group in groups {
                        let allEmojisInGroup = group.emojis.map { $0.char }
                        
                        for emoji in group.emojis {
                            if let variations = emoji.variations, !variations.isEmpty {
                                variationsMap[emoji.char] = variations.map { $0.char }
                            }
                        }
                        
                        let icon = allEmojisInGroup.first ?? "❓"
                        loadedCategories.append(EmojiCategory(
                            title: group.groupName,
                            icon: icon,
                            emojis: allEmojisInGroup
                        ))
                    }
                }
            }
        }
        
        self.baseCategories = loadedCategories
        self.emojiToVariations = variationsMap
        
        // 2. 최근 사용 기록 로드
        loadRecents()
    }

    // MARK: - Recent Emojis Management
    
    func addRecentEmoji(_ emoji: String) {
        // 기존 목록에서 중복 제거
        if let index = recentEmojis.firstIndex(of: emoji) {
            recentEmojis.remove(at: index)
        }
        
        // 맨 앞에 추가
        recentEmojis.insert(emoji, at: 0)
        
        // 개수 제한
        if recentEmojis.count > maxRecentCount {
            recentEmojis = Array(recentEmojis.prefix(maxRecentCount))
        }
        
        saveRecents()
    }
    
    private func loadRecents() {
        if let saved = UserDefaults.standard.stringArray(forKey: recentKey) {
            self.recentEmojis = saved
        }
    }
    
    private func saveRecents() {
        UserDefaults.standard.set(recentEmojis, forKey: recentKey)
    }

    // MARK: - Logic
    
    func supportsSkinTone(_ emoji: String) -> Bool {
        return emojiToVariations[emoji] != nil
    }

    func getVariations(for emoji: String) -> [String] {
        if let variations = emojiToVariations[emoji] {
            return [emoji] + variations
        }
        return [emoji]
    }
}
