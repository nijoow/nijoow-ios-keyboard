import Foundation
import UIKit

enum KeyboardThemePreset: String, Codable, CaseIterable, Identifiable, Sendable {
  case obsidian
  case frost
  case amethyst
  case sage
  case rose
  case custom

  var id: String { rawValue }

  var title: String {
    switch self {
    case .obsidian: "Obsidian"
    case .frost: "Frost"
    case .amethyst: "Amethyst"
    case .sage: "Sage"
    case .rose: "Rose"
    case .custom: "직접 선택"
    }
  }

  var defaultAccent: KeyboardRGBA {
    switch self {
    case .obsidian: KeyboardRGBA(red: 0.58, green: 0.60, blue: 0.66)
    case .frost: KeyboardRGBA(red: 0.38, green: 0.66, blue: 0.96)
    case .amethyst: KeyboardRGBA(red: 0.60, green: 0.48, blue: 0.94)
    case .sage: KeyboardRGBA(red: 0.36, green: 0.72, blue: 0.61)
    case .rose: KeyboardRGBA(red: 0.88, green: 0.48, blue: 0.62)
    case .custom: KeyboardRGBA.defaultCustomAccent
    }
  }
}

enum KeyboardHeightPreset: String, Codable, CaseIterable, Identifiable, Sendable {
  case compact
  case standard
  case large

  var id: String { rawValue }

  var title: String {
    switch self {
    case .compact: "컴팩트"
    case .standard: "기본"
    case .large: "크게"
    }
  }

  var rowScale: CGFloat {
    switch self {
    case .compact: 0.92
    case .standard: 1.0
    case .large: 1.08
    }
  }

  var fontScale: CGFloat {
    switch self {
    case .compact: 0.96
    case .standard: 1.0
    case .large: 1.04
    }
  }
}

struct KeyboardRGBA: Codable, Equatable, Sendable {
  static let defaultCustomAccent = KeyboardRGBA(red: 0.38, green: 0.66, blue: 0.96)

  let red: Double
  let green: Double
  let blue: Double

  init(red: Double, green: Double, blue: Double) {
    self.red = Self.clamp(red)
    self.green = Self.clamp(green)
    self.blue = Self.clamp(blue)
  }

  init(color: UIColor) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
      self.init(red: Double(red), green: Double(green), blue: Double(blue))
    } else {
      self = .defaultCustomAccent
    }
  }

  var uiColor: UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: 1)
  }

  private static func clamp(_ value: Double) -> Double {
    min(max(value, 0), 1)
  }
}

struct KeyboardSettings: Codable, Equatable, Sendable {
  static let currentSchemaVersion = 1
  static let `default` = KeyboardSettings()

  var schemaVersion: Int
  var theme: KeyboardThemePreset
  var customAccent: KeyboardRGBA
  var height: KeyboardHeightPreset
  var hapticsEnabled: Bool

  init(
    schemaVersion: Int = Self.currentSchemaVersion,
    theme: KeyboardThemePreset = .obsidian,
    customAccent: KeyboardRGBA = .defaultCustomAccent,
    height: KeyboardHeightPreset = .standard,
    hapticsEnabled: Bool = false
  ) {
    self.schemaVersion = schemaVersion
    self.theme = theme
    self.customAccent = customAccent
    self.height = height
    self.hapticsEnabled = hapticsEnabled
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion =
      try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
      ?? Self.currentSchemaVersion
    theme = try container.decodeIfPresent(KeyboardThemePreset.self, forKey: .theme) ?? .obsidian
    customAccent =
      try container.decodeIfPresent(KeyboardRGBA.self, forKey: .customAccent)
      ?? .defaultCustomAccent
    height =
      try container.decodeIfPresent(KeyboardHeightPreset.self, forKey: .height) ?? .standard
    hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? false
    schemaVersion = Self.currentSchemaVersion
  }

  var accent: KeyboardRGBA {
    theme == .custom ? customAccent : theme.defaultAccent
  }
}

enum KeyboardPreferencesStore {
  static let appGroupIdentifier = "group.nijoow.custom.keyboard"
  private static let settingsKey = "keyboard.settings.v1"

  static func load() -> KeyboardSettings {
    guard let data = defaults?.data(forKey: settingsKey),
      let settings = try? JSONDecoder().decode(KeyboardSettings.self, from: data)
    else {
      return .default
    }
    return settings
  }

  @discardableResult
  static func save(_ settings: KeyboardSettings) -> Bool {
    guard let defaults, let data = try? JSONEncoder().encode(settings) else { return false }
    defaults.set(data, forKey: settingsKey)
    return true
  }

  static func reset() {
    defaults?.removeObject(forKey: settingsKey)
  }

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupIdentifier)
  }
}
