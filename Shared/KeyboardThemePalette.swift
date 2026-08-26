import UIKit

struct KeyboardThemePalette {
  let accent: UIColor
  let keyboardBackground: UIColor
  let keyBackground: UIColor
  let specialKeyBackground: UIColor
  let activeKeyBackground: UIColor
  let keyText: UIColor
  let specialKeyText: UIColor
  let glassBodyColors: [UIColor]
  let rimColors: [UIColor]
  let dragOverlay: UIColor
  let dragRing: UIColor
  let emojiBackground: UIColor
  let emojiBorder: UIColor

  static func make(for settings: KeyboardSettings) -> KeyboardThemePalette {
    let accent = normalizedAccent(settings.accent.uiColor)
    let neutralKey = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    let neutralSpecial = UIColor(red: 0.025, green: 0.025, blue: 0.035, alpha: 1)
    let background = blend(
      UIColor(red: 0.018, green: 0.018, blue: 0.023, alpha: 1), accent, amount: 0.035)

    return KeyboardThemePalette(
      accent: accent,
      // 키보드 루트는 모든 테마에서 투명하다. 테마는 개별 키와 패널 표면에만 적용해
      // 호스트 앱 위에 불필요한 단색 판이 생기지 않게 한다.
      keyboardBackground: .clear,
      keyBackground: blend(neutralKey, accent, amount: 0.10).withAlphaComponent(0.40),
      specialKeyBackground: blend(neutralSpecial, accent, amount: 0.075).withAlphaComponent(0.24),
      activeKeyBackground: blend(accent, .white, amount: 0.16).withAlphaComponent(0.88),
      keyText: .white,
      specialKeyText: UIColor(white: 0.78, alpha: 1),
      glassBodyColors: [
        blend(.white, accent, amount: 0.10).withAlphaComponent(0.22),
        blend(.white, accent, amount: 0.16).withAlphaComponent(0.09),
        accent.withAlphaComponent(0.025),
        UIColor(white: 0, alpha: 0.08),
      ],
      rimColors: [
        blend(.white, accent, amount: 0.10).withAlphaComponent(0.52),
        blend(.white, accent, amount: 0.22).withAlphaComponent(0.14),
        UIColor(white: 0, alpha: 0.24),
      ],
      dragOverlay: UIColor(white: 0, alpha: 0.48),
      dragRing: blend(accent, .white, amount: 0.25).withAlphaComponent(0.82),
      emojiBackground: background.withAlphaComponent(0.97),
      emojiBorder: blend(.white, accent, amount: 0.12).withAlphaComponent(0.16)
    )
  }

  private static func normalizedAccent(_ color: UIColor) -> UIColor {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0

    guard color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    else {
      return KeyboardRGBA.defaultCustomAccent.uiColor
    }

    let safeBrightness = min(max(brightness, 0.58), 0.92)
    // 무채색을 임의의 붉은색으로 바꾸지 않는다. 채도가 있는 색만 글래스 UI에서
    // 구분 가능한 범위로 정규화한다.
    if saturation < 0.05 {
      return UIColor(white: safeBrightness, alpha: 1)
    }

    // 너무 탁하거나 형광색인 선택도 글래스 UI에서 읽기 좋은 범위로 정규화한다.
    let safeSaturation = min(max(saturation, 0.28), 0.78)
    return UIColor(hue: hue, saturation: safeSaturation, brightness: safeBrightness, alpha: 1)
  }

  private static func blend(_ first: UIColor, _ second: UIColor, amount: CGFloat) -> UIColor {
    let lhs = components(of: first)
    let rhs = components(of: second)
    let ratio = min(max(amount, 0), 1)
    return UIColor(
      red: lhs.red + (rhs.red - lhs.red) * ratio,
      green: lhs.green + (rhs.green - lhs.green) * ratio,
      blue: lhs.blue + (rhs.blue - lhs.blue) * ratio,
      alpha: lhs.alpha + (rhs.alpha - lhs.alpha) * ratio
    )
  }

  private static func components(of color: UIColor) -> (
    red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat
  ) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue, alpha)
  }
}
