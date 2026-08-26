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

  private init() {}

  func configure(isEnabled: Bool) {
    guard self.isEnabled != isEnabled else {
      if isEnabled { generator?.prepare() }
      return
    }

    self.isEnabled = isEnabled
    lastRepeatTimestamp = 0

    if isEnabled {
      let generator = UIImpactFeedbackGenerator(style: .soft)
      self.generator = generator
      generator.prepare()
    } else {
      generator = nil
    }
  }

  func prepare() {
    guard isEnabled else { return }
    generator?.prepare()
  }

  func playKeyPress() {
    emit(intensity: 0.52)
  }

  func playRepeat(_ kind: RepeatKind) {
    guard isEnabled else { return }

    let now = ProcessInfo.processInfo.systemUptime
    guard now - lastRepeatTimestamp >= minimumRepeatInterval else { return }
    lastRepeatTimestamp = now

    let intensity: CGFloat = kind == .cursor ? 0.32 : 0.38
    emit(intensity: intensity)
  }

  private func emit(intensity: CGFloat) {
    guard isEnabled, let generator else { return }
    generator.impactOccurred(intensity: intensity)
    KeyboardInputDiagnostics.shared.recordHaptic()
    generator.prepare()
  }
}
