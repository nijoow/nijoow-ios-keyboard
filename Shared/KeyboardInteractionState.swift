import Foundation

enum KeyboardLanguage: Equatable, Sendable {
  case hangul
  case english
}

enum KeyboardSymbolPage: Equatable, Sendable {
  case primary
  case secondary

  mutating func toggle() {
    self = self == .primary ? .secondary : .primary
  }
}

enum KeyboardPanel: Equatable, Sendable {
  case letters
  case symbols(KeyboardSymbolPage)
  case emoji
}

enum KeyboardShiftState: Equatable, Sendable {
  case off
  case oneShot
  case locked
}

/// 키보드 모드 전이의 단일 원본. UI는 이 값을 표시만 하고 직접 boolean을 조합하지 않는다.
struct KeyboardInteractionState: Equatable, Sendable {
  private(set) var language: KeyboardLanguage = .hangul
  private(set) var panel: KeyboardPanel = .letters
  private(set) var shift: KeyboardShiftState = .off
  private(set) var lastShiftTapUptime: TimeInterval?

  var isHangul: Bool { language == .hangul }
  var isSymbol: Bool {
    if case .symbols = panel { return true }
    return false
  }
  var isEmoji: Bool { panel == .emoji }
  var isShifted: Bool {
    switch panel {
    case .symbols(.secondary): return true
    case .letters: return shift != .off
    case .symbols(.primary), .emoji: return false
    }
  }
  var isShiftLocked: Bool { panel == .letters && shift == .locked }

  mutating func restoreLanguage(isHangul: Bool) {
    language = isHangul ? .hangul : .english
  }

  mutating func tapShift(at uptime: TimeInterval, doubleTapInterval: TimeInterval) {
    switch panel {
    case .symbols(var page):
      page.toggle()
      panel = .symbols(page)
      lastShiftTapUptime = nil
    case .emoji:
      lastShiftTapUptime = nil
    case .letters:
      if shift == .locked {
        shift = .off
        lastShiftTapUptime = nil
      } else if let previous = lastShiftTapUptime,
        uptime - previous >= 0,
        uptime - previous < doubleTapInterval
      {
        shift = .locked
        lastShiftTapUptime = nil
      } else {
        shift = shift == .oneShot ? .off : .oneShot
        lastShiftTapUptime = uptime
      }
    }
  }

  mutating func lockShift() {
    guard panel == .letters else { return }
    shift = .locked
    lastShiftTapUptime = nil
  }

  @discardableResult
  mutating func consumeOneShotShift() -> Bool {
    guard panel == .letters, shift == .oneShot else { return false }
    shift = .off
    lastShiftTapUptime = nil
    return true
  }

  mutating func cancelShiftTapCandidate() {
    lastShiftTapUptime = nil
  }

  mutating func resetShift() {
    shift = .off
    lastShiftTapUptime = nil
    if case .symbols = panel {
      panel = .symbols(.primary)
    }
  }

  mutating func toggleLanguage() {
    language = language == .hangul ? .english : .hangul
    panel = .letters
    shift = .off
    lastShiftTapUptime = nil
  }

  mutating func toggleSymbols() {
    panel = isSymbol ? .letters : .symbols(.primary)
    shift = .off
    lastShiftTapUptime = nil
  }

  mutating func toggleEmoji() {
    panel = isEmoji ? .letters : .emoji
    shift = .off
    lastShiftTapUptime = nil
  }

  mutating func leaveEmojiPanel() {
    guard isEmoji else { return }
    panel = .letters
  }
}

enum CursorMovement: Equatable, Sendable {
  case lineStart
  case left
  case right
  case lineEnd
}

enum KeyboardAction: Equatable, Sendable {
  case character(String)
  case shift
  case lockShift
  case backspace
  case moveCursor(CursorMovement)
  case space
  case switchLanguage
  case toggleSymbols
  case toggleEmoji
  case enter
  case dismiss
  case nextKeyboard

  var activationPolicy: KeyboardActivationPolicy {
    switch self {
    case .character, .backspace, .moveCursor:
      return .pressDown
    case .shift, .lockShift, .space, .switchLanguage, .toggleSymbols, .toggleEmoji,
      .enter, .dismiss, .nextKeyboard:
      return .releaseInside
    }
  }
}

enum KeyboardActivationPolicy: Equatable, Sendable {
  case pressDown
  case releaseInside
}

/// 백스페이스를 누른 시간에 따라 한 tick에서 지울 문자 수를 늘린다.
/// 줄바꿈을 특별 취급하지 않으므로 문단 경계에서도 같은 속도로 계속 삭제한다.
struct BackspaceRepeatProfile: Equatable, Sendable {
  let interval: TimeInterval
  let batchSize: Int

  static func profile(heldDuration: TimeInterval) -> BackspaceRepeatProfile {
    switch max(heldDuration, 0) {
    case ..<1.3:
      BackspaceRepeatProfile(interval: 0.075, batchSize: 1)
    case ..<2.8:
      BackspaceRepeatProfile(interval: 0.060, batchSize: 2)
    case ..<5.0:
      BackspaceRepeatProfile(interval: 0.050, batchSize: 3)
    default:
      BackspaceRepeatProfile(interval: 0.050, batchSize: 4)
    }
  }
}

enum KeyboardLayoutClass: Equatable, Sendable {
  case compactPhone
  case widePhone
  case regularPad
  case widePad

  static func classify(width: CGFloat, isPad: Bool) -> KeyboardLayoutClass {
    let safeWidth = max(width, 0)
    if isPad, safeWidth >= 700 {
      return safeWidth >= 1_000 ? .widePad : .regularPad
    }
    return safeWidth >= 600 ? .widePhone : .compactPhone
  }
}
