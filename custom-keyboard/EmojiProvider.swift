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
  
  // 기본 카테고리 데이터 (JSON에서 로드된 것) — 지연 로딩
  private var baseCategories: [EmojiCategory] = []
  
  // 최근 사용 이모지 목록
  private(set) var recentEmojis: [String] = []
  private let recentKey = "nijoow.custom.keyboard.recentEmojis"
  private let maxRecentCount = 40
  
  // 로드 상태 추적
  private var isLoaded = false
  
  // UI에 제공할 최종 카테고리 목록 (최근 사용 포함) - 메모리 최적화를 위해 캐싱 처리
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
    // 최근 사용 기록만 로드 (가벼움 — UserDefaults에서 문자열 배열 읽기)
    loadRecents()
  }
  
  // MARK: - 지연 로딩 (이모지 패널이 열릴 때만)
  
  /// 이모지 JSON 데이터를 로드합니다. 이모지 패널이 열릴 때 자동 호출됩니다.
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
    
    // 캐시 갱신
    updateCategoriesCache()
  }
  
  /// 메모리 부족 시 이모지 데이터를 해제합니다. 다음 접근 시 자동으로 다시 로드됩니다.
  func unloadData() {
    baseCategories = []
    emojiToVariations = [:]
    _cachedCategories = []
    isLoaded = false
  }

  // MARK: - Recent Emojis Management
  
  func addRecentEmoji(_ custom: String) {
    // 기존 목록에서 중복 제거
    if let index = recentEmojis.firstIndex(of: custom) {
      recentEmojis.remove(at: index)
    }
    
    // 맨 앞에 추가
    recentEmojis.insert(custom, at: 0)
    
    // 개수 제한
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

  // MARK: - Variation Logic
  
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
