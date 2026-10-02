import UIKit

extension KeyboardViewController {
  func buildNumericKeyboard() {
    let content = keyboardContentView
    let grid = ExpandedHitStackView()
    grid.axis = .vertical
    grid.spacing = 5
    grid.distribution = .fillEqually
    grid.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(grid)
    mainContentStack = grid

    for keys in inputLayout.rows(decimalSeparator: Locale.current.decimalSeparator ?? ".") {
      let row = ExpandedHitStackView()
      row.axis = .horizontal
      row.distribution = .fillEqually
      row.spacing = 5
      for value in keys {
        let isDelete = value == KeyboardConstants.KeyID.backspace
        let button = makeGlassButton(title: isDelete ? "⌫" : value, id: value, isSpecial: isDelete,
                                     fontSize: layoutMetrics.keyFontSize + 4)
        if isDelete {
          button.accessibilityLabel = "삭제"
          button.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
          button.addTarget(self, action: #selector(backspaceTouchUp(_:)),
                           for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        row.addArrangedSubview(button)
        row.registerKey(button)
      }
      if keys.count == 2 {
        row.distribution = .fill
        row.arrangedSubviews[0].widthAnchor.constraint(
          equalTo: row.arrangedSubviews[1].widthAnchor, multiplier: 2, constant: row.spacing
        ).isActive = true
      }
      grid.addArrangedSubview(row)
    }

    let footer = ExpandedHitStackView()
    footer.axis = .horizontal
    footer.spacing = 5
    footer.distribution = .fillEqually
    footer.translatesAutoresizingMaskIntoConstraints = false
    content.addSubview(footer)
    bottomRow = footer

    let globe = makeGlassButton(title: "", id: KeyboardConstants.KeyID.nextKeyboard, isSpecial: true)
    globe.setImage(UIImage(systemName: "globe"), for: .normal)
    globe.tintColor = specialTextColor
    globe.accessibilityLabel = "다음 키보드"
    globe.acceptsGapHitRouting = false
    globe.isHidden = !needsInputModeSwitchKey
    globe.addTarget(self, action: #selector(nextKeyboardTapped), for: .touchUpInside)
    nextKeyboardButton = globe
    footer.addArrangedSubview(globe)
    footer.registerKey(globe)

    if inputLayout == .phone {
      for value in ["*", "#"] {
        let button = makeGlassButton(title: value, id: value, isSpecial: false)
        footer.addArrangedSubview(button)
        footer.registerKey(button)
      }
    }

    let done = makeGlassButton(title: "완료", id: KeyboardConstants.KeyID.dismiss, isSpecial: true)
    done.accessibilityLabel = "키보드 닫기"
    done.acceptsGapHitRouting = false
    done.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    footer.addArrangedSubview(done)
    footer.registerKey(done)

    NSLayoutConstraint.activate([
      grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 6),
      grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
      grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
      grid.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -7),
      footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
      footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
      footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
      footer.heightAnchor.constraint(equalToConstant: layoutMetrics.bottomRowH),
    ])
    lastRenderedPanel = interactionState.panel
    keyboardContentView.keyRows = grid.arrangedSubviews + [footer]
  }

}
