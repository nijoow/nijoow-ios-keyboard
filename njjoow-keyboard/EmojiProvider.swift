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
    
    let categories: [EmojiCategory]
    private var emojiToVariations: [String: [String]] = [:]
    
    private init() {
        var loadedCategories: [EmojiCategory] = []
        var variationsMap: [String: [String]] = [:]
        
        autoreleasepool {
            if let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
               let data = try? Data(contentsOf: url) {
                
                let decoder = JSONDecoder()
                if let groups = try? decoder.decode([EmojiGroup].self, from: data) {
                    for group in groups {
                        let allEmojisInGroup = group.emojis.map { $0.char }
                        
                        // 변체(variations) 맵 구축 최적화
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
        
        self.categories = loadedCategories
        self.emojiToVariations = variationsMap
    }

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
