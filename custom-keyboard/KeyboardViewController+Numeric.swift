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

    for keys in numericKeyRows {
      let row = ExpandedHitStackView()
      row.axis = .horizontal
      row.distribution = .fillEqually
      row.spacing = 5
      for value in keys {
        let isDelete = value == KeyboardConstants.KeyID.backspace
        let isToggle = value == KeyboardConstants.KeyID.symbol
        let button = makeGlassButton(title: "", id: value, isSpecial: isDelete || isToggle,
                                     fontSize: isToggle ? layoutMetrics.keyFontSize : layoutMetrics.keyFontSize + 4)
        configureNumericKey(button, value: value)
        if isDelete {
          button.accessibilityLabel = "삭제"
          button.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
          button.addTarget(self, action: #selector(backspaceTouchUp(_:)),
                           for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        if isToggle {
          button.addTarget(self, action: #selector(symbolTapped), for: .touchUpInside)
        }
        row.addArrangedSubview(button)
        row.registerKey(button)
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

  private var numericKeyRows: [[String]] {
    inputLayout.rows(decimalSeparator: Locale.current.decimalSeparator ?? ".",
                     showsSymbols: showsNumericSymbols)
  }

  /// 기호 전환은 동일한 버튼을 재사용해 터치 영역과 뷰 계층을 유지한다.
  func updateNumericKeyLabels() {
    guard inputLayout == .number, let grid = mainContentStack else { return }
    UIView.performWithoutAnimation {
      for (row, values) in zip(grid.arrangedSubviews, numericKeyRows) {
        guard let row = row as? UIStackView else { continue }
        for (view, value) in zip(row.arrangedSubviews, values) {
          guard let button = view as? KeyButton else { continue }
          configureNumericKey(button, value: value)
        }
      }
    }
  }

  private func configureNumericKey(_ button: KeyButton, value: String) {
    button.keyValue = value
    switch value {
    case KeyboardConstants.KeyID.symbol:
      button.setTitle(showsNumericSymbols ? "123" : "#+=", for: .normal)
      button.accessibilityLabel = showsNumericSymbols ? "숫자 키패드로 전환" : "기호 키패드로 전환"
    case KeyboardConstants.KeyID.backspace:
      button.setTitle("⌫", for: .normal)
      button.accessibilityLabel = "삭제"
    default:
      button.setTitle(value, for: .normal)
      button.accessibilityLabel = value
    }
  }
}
