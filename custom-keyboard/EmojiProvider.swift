import Foundation

/// [경량화] 최적화된 JSON 구조에 맞춘 이모지 항목 모델
struct EmojiItem: Codable {
  let char: String
  let variations: [EmojiItem]?
}

/// [경량화] subGroups 단계가 제거된 단순화된 그룹 모델
struct EmojiGroup: Codable {
  let groupName: String
  let customs: [EmojiItem]
}

struct EmojiCategory: Codable {
  let title: String
  let icon: String
  let emojis: [String]
}

class EmojiProvider {
  static let shared = EmojiProvider()
  
  private var baseCategories: [EmojiCategory] = []
  
  private(set) var recentEmojis: [String] = []
  private let recentKey = "nijoow.custom.keyboard.recentEmojis"
  private let maxRecentCount = 40
  
  private var isLoaded = false
  
  private var _cachedCategories: [EmojiCategory] = [];
  var categories: [EmojiCategory] {
    loadIfNeeded()
    if _cachedCategories.isEmpty { updateCategoriesCache(); }
    return _cachedCategories;
  }
  
  private func updateCategoriesCache() {
    if recentEmojis.isEmpty {
      _cachedCategories = baseCategories;
    } else {
      let recentCategory = EmojiCategory(
        title: "최근 사용",
        icon: "🕒",
        emojis: recentEmojis
      );
      _cachedCategories = [recentCategory] + baseCategories;
    }
  }
  
  private var emojiToVariations: [String: [String]] = [:]
  
  // MARK: - 초기화 (최근 사용 기록만 로드)
  
  private init() {
    loadRecents()
  }
  
  // MARK: - 지연 로딩 (이모지 패널이 열릴 때만)
  
  func loadIfNeeded() {
    guard !isLoaded else { return }
    isLoaded = true
    
    autoreleasepool {
      guard let url = Bundle.main.url(forResource: "emoji", withExtension: "json"),
            let data = try? Data(contentsOf: url) else { return }
      
      let decoder = JSONDecoder()
      guard let groups = try? decoder.decode([EmojiGroup].self, from: data) else { return }
      
      var loadedCategories: [EmojiCategory] = []
      var variationsMap: [String: [String]] = [:]
      
      for group in groups {
        let allEmojisInGroup = group.customs.map { $0.char }
        
        for emoji in group.customs {
          if let variations = emoji.variations, !variations.isEmpty {
            variationsMap[emoji.char] = variations.map { $0.char }
          }
        }
        
        loadedCategories.append(EmojiCategory(
          title: group.groupName,
          icon: allEmojisInGroup.first ?? "❓",
          emojis: allEmojisInGroup
        ))
      }
      
      self.baseCategories = loadedCategories
      self.emojiToVariations = variationsMap
    }
    
    updateCategoriesCache()
  }
  
  func unloadData() {
    baseCategories = []
    emojiToVariations = [:]
    _cachedCategories = []
    isLoaded = false
  }

  // MARK: - 최근 사용 이모지 관리
  
  func addRecentEmoji(_ custom: String) {
    if let index = recentEmojis.firstIndex(of: custom) {
      recentEmojis.remove(at: index)
    }
    
    recentEmojis.insert(custom, at: 0)
    
    if recentEmojis.count > maxRecentCount {
      recentEmojis = Array(recentEmojis.prefix(maxRecentCount))
    }
    
    saveRecents();
    updateCategoriesCache();
  }
  
  private func loadRecents() {
    if let saved = UserDefaults.standard.stringArray(forKey: recentKey) {
      self.recentEmojis = saved
    }
  }
  
  private func saveRecents() {
    UserDefaults.standard.set(recentEmojis, forKey: recentKey)
  }

  // MARK: - 변형(Skin Tone) 로직
  
  func supportsSkinTone(_ custom: String) -> Bool {
    return emojiToVariations[custom] != nil
  }

  func getVariations(for custom: String) -> [String] {
    if let variations = emojiToVariations[custom] {
      return [custom] + variations
    }
    return [custom]
  }
}
