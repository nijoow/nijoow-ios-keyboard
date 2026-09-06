import UIKit

@MainActor
final class KeyboardHaptics {
  static let shared = KeyboardHaptics()

  enum RepeatKind: Equatable {
    case cursor
    case backspace
  }

  private let minimumRepeatInterval: TimeInterval = 0.045
  private var generator: UIImpactFeedbackGenerator?
  private var lastRepeatTimestamp: TimeInterval = 0
  private(set) var isEnabled = false
  private(set) var strength: KeyboardHapticStrength = .standard

  private init() {}

  func configure(isEnabled: Bool, strength: KeyboardHapticStrength) {
    guard self.isEnabled != isEnabled || self.strength != strength else {
      if isEnabled { prepare() }
      return
    }

    self.isEnabled = isEnabled
    self.strength = strength
    lastRepeatTimestamp = 0

    if isEnabled {
      prepare()
    } else {
      generator = nil
    }
  }

  func prepare() {
    guard isEnabled else { return }
    makeGeneratorIfNeeded().prepare()
  }

  /// 키보드가 화면에서 내려간 동안 Taptic Engine 관련 객체를 붙잡아 두지 않는다.
  /// 활성화 설정은 유지하므로 다음 등장 시 `prepare()`가 가볍게 다시 만든다.
  func suspend() {
    generator = nil
    lastRepeatTimestamp = 0
  }

  func playKeyPress() {
    emit(baseIntensity: 0.52)
  }

  func playRepeat(_ kind: RepeatKind) {
    guard isEnabled else { return }

    let now = ProcessInfo.processInfo.systemUptime
    guard now - lastRepeatTimestamp >= minimumRepeatInterval else { return }
    lastRepeatTimestamp = now

    let baseIntensity: CGFloat = kind == .cursor ? 0.32 : 0.38
    emit(baseIntensity: baseIntensity)
  }

  private func emit(baseIntensity: CGFloat) {
    guard isEnabled else { return }
    let generator = makeGeneratorIfNeeded()
    generator.impactOccurred(intensity: strength.intensity(for: baseIntensity))
    KeyboardInputDiagnostics.shared.recordHaptic()
    generator.prepare()
  }

  private func makeGeneratorIfNeeded() -> UIImpactFeedbackGenerator {
    if let generator { return generator }
    let generator = UIImpactFeedbackGenerator(style: .soft)
    self.generator = generator
    return generator
  }
}
