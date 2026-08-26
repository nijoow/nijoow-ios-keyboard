import UIKit
import XCTest

@testable import keyboard

@MainActor
final class KeyboardSettingsTests: XCTestCase {
  func testDefaultSettingsKeepHapticsOff() {
    let settings = KeyboardSettings.default

    XCTAssertEqual(settings.theme, .obsidian)
    XCTAssertEqual(settings.height, .standard)
    XCTAssertFalse(settings.hapticsEnabled)
  }

  func testSettingsRoundTripPreservesUserChoices() throws {
    let source = KeyboardSettings(
      theme: .custom,
      customAccent: KeyboardRGBA(red: 0.22, green: 0.74, blue: 0.51),
      height: .large,
      hapticsEnabled: true
    )

    let encoded = try JSONEncoder().encode(source)
    let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: encoded)

    XCTAssertEqual(decoded, source)
  }

  func testOlderSettingsReceiveSafeDefaults() throws {
    let encoded = Data(#"{"theme":"frost"}"#.utf8)

    let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: encoded)

    XCTAssertEqual(decoded.theme, .frost)
    XCTAssertEqual(decoded.height, .standard)
    XCTAssertFalse(decoded.hapticsEnabled)
    XCTAssertEqual(decoded.schemaVersion, KeyboardSettings.currentSchemaVersion)
  }

  func testCustomColorComponentsAreClamped() {
    let color = KeyboardRGBA(red: -1, green: 0.5, blue: 2)

    XCTAssertEqual(color.red, 0)
    XCTAssertEqual(color.green, 0.5)
    XCTAssertEqual(color.blue, 1)
  }

  func testHeightPresetsRemainOrdered() {
    XCTAssertLessThan(KeyboardHeightPreset.compact.rowScale, KeyboardHeightPreset.standard.rowScale)
    XCTAssertLessThan(KeyboardHeightPreset.standard.rowScale, KeyboardHeightPreset.large.rowScale)
    XCTAssertLessThanOrEqual(KeyboardHeightPreset.large.fontScale, KeyboardHeightPreset.large.rowScale)
  }

  func testPresetPalettesProduceDifferentAccents() {
    let frost = KeyboardThemePalette.make(for: KeyboardSettings(theme: .frost)).accent
    let rose = KeyboardThemePalette.make(for: KeyboardSettings(theme: .rose)).accent

    XCTAssertNotEqual(KeyboardRGBA(color: frost), KeyboardRGBA(color: rose))
  }

  func testNeutralCustomAccentStaysNeutral() {
    let settings = KeyboardSettings(
      theme: .custom, customAccent: KeyboardRGBA(red: 0.5, green: 0.5, blue: 0.5))
    let accent = KeyboardRGBA(color: KeyboardThemePalette.make(for: settings).accent)

    XCTAssertEqual(accent.red, accent.green, accuracy: 0.001)
    XCTAssertEqual(accent.green, accent.blue, accuracy: 0.001)
  }
}
