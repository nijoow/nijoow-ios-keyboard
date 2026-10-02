import UIKit
import XCTest

@MainActor
final class KeyboardSettingsTests: XCTestCase {
  func testDefaultSettingsKeepHapticsOff() {
    let settings = KeyboardSettings.default

    XCTAssertEqual(settings.theme, .obsidian)
    XCTAssertEqual(settings.height, .standard)
    XCTAssertFalse(settings.hapticsEnabled)
    XCTAssertEqual(settings.hapticStrength, .standard)
  }

  func testSettingsRoundTripPreservesUserChoices() throws {
    let source = KeyboardSettings(
      theme: .custom,
      customAccent: KeyboardRGBA(red: 0.22, green: 0.74, blue: 0.51),
      height: .large,
      hapticsEnabled: true,
      hapticStrength: .strong
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
    XCTAssertEqual(decoded.hapticStrength, .standard)
    XCTAssertEqual(decoded.schemaVersion, KeyboardSettings.currentSchemaVersion)
  }

  func testCustomColorComponentsAreClamped() {
    let color = KeyboardRGBA(red: -1, green: 0.5, blue: 2)

    XCTAssertEqual(color.red, 0)
    XCTAssertEqual(color.green, 0.5)
    XCTAssertEqual(color.blue, 1)
  }

  func testDecodedColorComponentsAreAlsoClamped() throws {
    let encoded = Data(#"{"red":-2,"green":0.4,"blue":3}"#.utf8)

    let decoded = try JSONDecoder().decode(KeyboardRGBA.self, from: encoded)

    XCTAssertEqual(decoded, KeyboardRGBA(red: 0, green: 0.4, blue: 1))
  }

  func testUnknownFutureFieldOnlyFallsBackThatField() throws {
    let encoded = Data(
      #"{"schemaVersion":99,"theme":"future-theme","customAccent":{"red":0.1,"green":0.2,"blue":0.3},"height":"large","hapticsEnabled":true,"hapticStrength":"strong"}"#.utf8)

    let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: encoded)

    XCTAssertEqual(decoded.schemaVersion, KeyboardSettings.currentSchemaVersion)
    XCTAssertEqual(decoded.theme, .obsidian)
    XCTAssertEqual(decoded.customAccent, KeyboardRGBA(red: 0.1, green: 0.2, blue: 0.3))
    XCTAssertEqual(decoded.height, .large)
    XCTAssertTrue(decoded.hapticsEnabled)
    XCTAssertEqual(decoded.hapticStrength, .strong)
  }

  func testInvalidFieldTypeDoesNotResetOtherSettings() throws {
    let encoded = Data(
      #"{"theme":"rose","height":17,"hapticsEnabled":true}"#.utf8)

    let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: encoded)

    XCTAssertEqual(decoded.theme, .rose)
    XCTAssertEqual(decoded.height, .standard)
    XCTAssertTrue(decoded.hapticsEnabled)
    XCTAssertEqual(decoded.hapticStrength, .standard)
  }

  func testExtensionConnectionStatusExpires() {
    let now = Date(timeIntervalSince1970: 10_000)
    let recent = KeyboardExtensionConnectionStatus(
      lastActivatedAt: now.addingTimeInterval(-60), hadFullAccess: true)
    let stale = KeyboardExtensionConnectionStatus(
      lastActivatedAt: now.addingTimeInterval(-600), hadFullAccess: true)

    XCTAssertTrue(recent.isRecent(referenceDate: now, maximumAge: 120))
    XCTAssertFalse(stale.isRecent(referenceDate: now, maximumAge: 120))
  }

  func testHeightPresetsRemainOrdered() {
    XCTAssertLessThan(KeyboardHeightPreset.compact.rowScale, KeyboardHeightPreset.standard.rowScale)
    XCTAssertLessThan(KeyboardHeightPreset.standard.rowScale, KeyboardHeightPreset.large.rowScale)
    XCTAssertLessThanOrEqual(KeyboardHeightPreset.large.fontScale, KeyboardHeightPreset.large.rowScale)
  }

  func testHapticStrengthsRemainOrdered() {
    let base: CGFloat = 0.52

    XCTAssertLessThan(
      KeyboardHapticStrength.light.intensity(for: base),
      KeyboardHapticStrength.standard.intensity(for: base))
    XCTAssertLessThan(
      KeyboardHapticStrength.standard.intensity(for: base),
      KeyboardHapticStrength.strong.intensity(for: base))
  }

  func testPresetPalettesProduceDifferentAccents() {
    let frost = KeyboardThemePalette.make(for: KeyboardSettings(theme: .frost)).accent
    let rose = KeyboardThemePalette.make(for: KeyboardSettings(theme: .rose)).accent

    XCTAssertNotEqual(KeyboardRGBA(color: frost), KeyboardRGBA(color: rose))
  }

  func testEveryThemeKeepsKeyboardRootBackgroundTransparent() {
    for preset in KeyboardThemePreset.allCases {
      let palette = KeyboardThemePalette.make(for: KeyboardSettings(theme: preset))
      XCTAssertEqual(
        palette.keyboardBackground.cgColor.alpha, 0,
        accuracy: 0.001,
        "\(preset.title) 테마가 키보드 루트 배경을 불투명하게 만들면 안 된다")
    }
  }

  func testNeutralCustomAccentStaysNeutral() {
    let settings = KeyboardSettings(
      theme: .custom, customAccent: KeyboardRGBA(red: 0.5, green: 0.5, blue: 0.5))
    let accent = KeyboardRGBA(color: KeyboardThemePalette.make(for: settings).accent)

    XCTAssertEqual(accent.red, accent.green, accuracy: 0.001)
    XCTAssertEqual(accent.green, accent.blue, accuracy: 0.001)
  }
}
