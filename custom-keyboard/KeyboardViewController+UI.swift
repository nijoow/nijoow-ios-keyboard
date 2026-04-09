//
//  KeyboardViewController+UI.swift
//  custom-keyboard
//

import UIKit

extension KeyboardViewController {
  
  // MARK: - 레이아웃 빌드
  
  func buildKeyboard() {
    view.subviews.forEach { $0.removeFromSuperview() }
    allKeyButtons.removeAll()
    shiftButton = nil
    
    let utilRow = makeUtilityRow()
    utilRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(utilRow)

    let botRow = makeBottomRow()
    botRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(botRow)

    NSLayoutConstraint.activate([
      utilRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
      utilRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      utilRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      utilRow.heightAnchor.constraint(equalToConstant: KeyboardConstants.UTIL_ROW_H),

      botRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
      botRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      botRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      botRow.heightAnchor.constraint(equalToConstant: KeyboardConstants.BOTTOM_ROW_H)
    ])

    if isCustom {
      setupCustomPanel(under: utilRow, above: botRow)
    } else {
      setupMainContentStack(under: utilRow, above: botRow)
    }
  }

  private func setupCustomPanel(under utilRow: UIView, above botRow: UIView) {
    let customView = CustomKeyboardView(isDarkMode: isDarkMode)
    customView.delegate = self
    customView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(customView)
    
    // 한영 키보드의 (숫자행 1 + 문자행 3 + 행간 간격 3 + 상하 여백 2) = 199pt
    let totalHeight: CGFloat = 185
    
    NSLayoutConstraint.activate([
      customView.topAnchor.constraint(equalTo: utilRow.bottomAnchor, constant: 7),
      customView.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
      customView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      customView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      customView.heightAnchor.constraint(equalToConstant: totalHeight)
    ])
    
    view.layoutIfNeeded()
  }

  private func setupMainContentStack(under utilRow: UIView, above botRow: UIView) {
    let contentStack = UIStackView()
    contentStack.axis = .vertical
    contentStack.distribution = .fill
    contentStack.spacing = 7
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(contentStack)

    NSLayoutConstraint.activate([
      contentStack.topAnchor.constraint(equalTo: utilRow.bottomAnchor, constant: 7),
      contentStack.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
      contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6)
    ])

    let numRow = makeNumberRow()
    numRow.heightAnchor.constraint(equalToConstant: KeyboardConstants.NUMBER_ROW_H).isActive = true
    contentStack.addArrangedSubview(numRow)

    if isSymbol {
      let rows = isShifted ? 
        [KeyboardConstants.SYM_ROW1_SHIFTED, KeyboardConstants.SYM_ROW2_SHIFTED, KeyboardConstants.SYM_ROW3_SHIFTED] :
        [KeyboardConstants.SYM_ROW1_NORMAL, KeyboardConstants.SYM_ROW2_NORMAL, KeyboardConstants.SYM_ROW3_NORMAL]
      
      let v1 = makeEqualRow(keys: rows[0], rowOffset: 400)
      let v2 = makeLetterRowStack(rows[1], rowOffset: 500) // 9키 대응 로직 사용
      let v3 = makeShiftRow(middleKeys: rows[2], keyValues: rows[2], rowOffset: 600) // 7키 대응 로직 사용
      
      [v1, v2, v3].forEach {
        $0.heightAnchor.constraint(equalToConstant: KeyboardConstants.MAIN_KEY_H).isActive = true
        contentStack.addArrangedSubview($0)
      }
    } else {
      let v1 = makeLetterRow1()
      let v2 = makeLetterRow2()
      let v3 = makeLetterShiftRow()
      
      [v1, v2, v3].forEach {
        $0.heightAnchor.constraint(equalToConstant: KeyboardConstants.MAIN_KEY_H).isActive = true
        contentStack.addArrangedSubview($0)
      }
    }
  }

  // MARK: - 요소 생성
  
  func makeUtilityRow() -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 5

    let cursors: [(CursorIconType, String)] = [
      (.lineStart, "cursor_line_start"), (.left, "cursor_left"),
      (.right, "cursor_right"), (.lineEnd, "cursor_line_end")
    ]
    
    for (type, id) in cursors {
      let btn = makeGlassButton(title: "", id: id, isSpecial: true)
      let img = drawCursorImage(type: type, size: CGSize(width: 32, height: 32))
      btn.setImage(img.withRenderingMode(.alwaysTemplate), for: .normal)
      btn.tintColor = specialTextColor
      
      // 가속 및 스마트 이동을 위한 핸들러 연결
      btn.accessibilityIdentifier = id
      btn.addTarget(self, action: #selector(cursorTouchDown(_:)), for: .touchDown)
      btn.addTarget(self, action: #selector(cursorTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
      
      stack.addArrangedSubview(btn)
    }

    let customBtn = makeGlassButton(title: "☺︎", id: "custom", isSpecial: true, fontSize: 26)
    if isCustom { customBtn.backgroundColor = activeGlassColor }
    customBtn.addTarget(self, action: #selector(customTapped), for: .touchUpInside)
    stack.addArrangedSubview(customBtn)

    let dismissBtn = makeGlassButton(title: "", id: "dismiss", isSpecial: true)
    let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    if let img = UIImage(systemName: "keyboard.chevron.compact.down", withConfiguration: config) {
      dismissBtn.setImage(img.withRenderingMode(.alwaysTemplate), for: .normal)
      dismissBtn.tintColor = specialTextColor
    }
    dismissBtn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    stack.addArrangedSubview(dismissBtn)

    return stack
  }

  func makeBottomRow() -> UIView {
    let container = UIView()
    container.clipsToBounds = false // 가장자리 터치 및 애니메이션 잘림 방지
    let symBtnTitle = isSymbol ? (isHangul ? "한글" : "ENG") : "♥︎"
    let symBtn = makeGlassButton(title: symBtnTitle, id: "symbol", isSpecial: true, tag: 201, fontSize:16)
    symBtn.addTarget(self, action: #selector(symbolTapped), for: .touchUpInside)

    let langBtn = makeGlassButton(title: isHangul ? "ENG" : "한글", id: "lang", isSpecial: true, tag: 202, fontSize:16)
    langBtn.addTarget(self, action: #selector(langTapped), for: .touchUpInside)

    let spaceBtn = makeGlassButton(title: "", id: " ", isSpecial: false, tag: 203)
    let dotBtn = makeGlassButton(title: ".", id: ".", isSpecial: false, tag: 204)
    let enterBtn = makeGlassButton(title: "↵", id: "enter", isSpecial: true, tag: 205)
    enterBtn.addTarget(self, action: #selector(enterTapped), for: .touchUpInside)

    [symBtn, langBtn, spaceBtn, dotBtn, enterBtn].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview($0)
    }

    NSLayoutConstraint.activate([
      symBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      symBtn.topAnchor.constraint(equalTo: container.topAnchor),
      symBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      symBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.13),

      langBtn.leadingAnchor.constraint(equalTo: symBtn.trailingAnchor, constant: 5),
      langBtn.topAnchor.constraint(equalTo: container.topAnchor),
      langBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      langBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.13),

      dotBtn.trailingAnchor.constraint(equalTo: enterBtn.leadingAnchor, constant: -5),
      dotBtn.topAnchor.constraint(equalTo: container.topAnchor),
      dotBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      dotBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.10),

      enterBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      enterBtn.topAnchor.constraint(equalTo: container.topAnchor),
      enterBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      enterBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.13),

      spaceBtn.leadingAnchor.constraint(equalTo: langBtn.trailingAnchor, constant: 5),
      spaceBtn.trailingAnchor.constraint(equalTo: dotBtn.leadingAnchor, constant: -5),
      spaceBtn.topAnchor.constraint(equalTo: container.topAnchor),
      spaceBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    return container
  }

  // 레거시 makeCustomPanel 제거됨 (CustomKeyboardView로 대체)

  // MARK: - 버튼 팩토리
  
  func makeGlassButton(title: String, id: String, isSpecial: Bool, tag: Int = 0, fontSize: CGFloat? = nil) -> KeyButton {
    let btn = KeyButton(type: .custom)
    btn.tag = tag
    btn.keyValue = id
    btn.setTitle(title, for: .normal)
    btn.titleLabel?.font = UIFont.systemFont(ofSize: fontSize ?? KeyboardConstants.KEY_FONT_SIZE, weight: isSpecial ? .medium : .regular)
    btn.setTitleColor(isSpecial ? specialTextColor : keyTextColor, for: .normal)
    btn.backgroundColor = isSpecial ? specialGlassColor : keyGlassColor
    btn.normalBackgroundColor = btn.backgroundColor
    
    btn.layer.cornerRadius = KeyboardConstants.CORNER_RADIUS
    btn.layer.borderWidth = 0.5
    btn.layer.borderColor = keyBorderColor
    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOffset = CGSize(width: 0, height: 1)
    btn.layer.shadowOpacity = isDarkMode ? 0.5 : 0.15
    btn.layer.shadowRadius = isDarkMode ? 4 : 2
    btn.isExclusiveTouch = true // 버튼 간 터치 간섭 방지
    
    btn.addTarget(self, action: #selector(hapticTouchDown(_:)), for: .touchDown)

    if !isSpecial {
      btn.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
      let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      lp.minimumPressDuration = 0.4
      btn.addGestureRecognizer(lp)
    }

    allKeyButtons.append(btn)
    return btn
  }

  func makeDummyButton() -> KeyButton {
    let btn = makeGlassButton(title: "", id: "dummy", isSpecial: true)
    btn.isUserInteractionEnabled = false // 터치 방지
    btn.alpha = 0.3 // 사용자 설정값: 실제 버튼보다 투명하게
    btn.layer.cornerRadius = 4 // 사용자 설정값: 약간의 곡률 유지
    return btn
  }

  // MARK: - 외관 업데이트
  
  func rebuildKeyboard() {
    if isCustom != wasCustom || isSymbol != wasSymbol {
      buildKeyboard()
      wasCustom = isCustom
      wasSymbol = isSymbol
    } else {
      updateKeyLabels()
      updateAppearance()
    }
  }

  func updateAppearance() {
    for btn in allKeyButtons {
      let id = btn.keyValue
      let isSpecial = (id == "shift" || id == "backspace" || id == "symbol" || id == "lang" || id == "enter" || id == "custom" || id == "dismiss" || id.contains("cursor"))
      
      if id == "shift" {
        let isActive = isShifted || isShiftLocked
        let activeColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.3) : UIColor(white: 0.0, alpha: 0.25)
        let normalColor = isSpecial ? specialGlassColor : keyGlassColor
        
        btn.backgroundColor = isActive ? activeColor : normalColor
        btn.normalBackgroundColor = btn.backgroundColor
        
        if isSymbol {
          btn.setTitle(isShifted ? "2/2" : "1/2", for: .normal)
          btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        } else {
          let shiftTitle = isShiftLocked ? "⇪" : "⇧"
          btn.setTitle(shiftTitle, for: .normal)
          btn.titleLabel?.font = UIFont.systemFont(ofSize: KeyboardConstants.KEY_FONT_SIZE, weight: .medium)
        }
        // continue를 제거하여 아래의 공통 속성(그림자, 테두리 등) 업데이트를 수행하도록 함
      }
      
      if id != "shift" {
        btn.backgroundColor = isSpecial ? specialGlassColor : keyGlassColor
        btn.normalBackgroundColor = btn.backgroundColor
      }
      
      btn.setTitleColor(isSpecial ? specialTextColor : keyTextColor, for: .normal)
      btn.tintColor = isSpecial ? specialTextColor : keyTextColor
      btn.layer.borderColor = keyBorderColor
      btn.layer.shadowOpacity = isDarkMode ? 0.5 : 0.15
    }
  }

  // MARK: - 개별 행 생성
  
  func makeNumberRow() -> UIView {
    makeEqualRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], rowOffset: 300)
  }

  func makeLetterRow1() -> UIView {
    makeLetterRowStack(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], rowOffset: 400)
  }

  func makeLetterRow2() -> UIView {
    makeLetterRowStack(["a", "s", "d", "f", "g", "h", "j", "k", "l"], rowOffset: 500)
  }

  func makeLetterShiftRow() -> UIView {
    let chars: [Character] = ["z", "x", "c", "v", "b", "n", "m"]
    let labels = chars.map { letterLabel(for: $0) }
    let keys = chars.map { String($0) }
    return makeShiftRow(middleKeys: labels, keyValues: keys, rowOffset: 600)
  }

  func makeLetterRowStack(_ chars: [String], rowOffset: Int) -> UIView {
    let container = UIView()
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fill
    stack.spacing = 5
    stack.translatesAutoresizingMaskIntoConstraints = false
    
    // 9개 버튼일 경우 양옆에 더미 버튼 추가
    if chars.count == 9 {
      let leftDummy = makeDummyButton()
      let rightDummy = makeDummyButton()
      
      stack.addArrangedSubview(leftDummy)
      
      var firstKey: UIView?
      for (idx, ch) in chars.enumerated() {
        let label = isSymbol ? ch : (ch.count == 1 ? letterLabel(for: Character(ch)) : ch)
        let key = makeGlassButton(title: label, id: ch, isSpecial: false, tag: rowOffset + idx)
        stack.addArrangedSubview(key)
        
        if let first = firstKey {
          // 모든 글자 키의 너비를 첫 번째 키와 동일하게 설정
          key.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true
        } else {
          firstKey = key
        }
      }
      
      stack.addArrangedSubview(rightDummy)
      
      // 더미 버튼의 너비를 일반 키의 0.3배로 설정 (사용자 설정값)
      if let key = firstKey {
        leftDummy.widthAnchor.constraint(equalTo: key.widthAnchor, multiplier: 0.3).isActive = true
        rightDummy.widthAnchor.constraint(equalTo: key.widthAnchor, multiplier: 0.3).isActive = true
      }
    } else {
      // 10개 버튼일 경우 (기존 fillEqually와 동일하게 동작)
      stack.distribution = .fillEqually
      for (idx, ch) in chars.enumerated() {
        let label = isSymbol ? ch : (ch.count == 1 ? letterLabel(for: Character(ch)) : ch)
        stack.addArrangedSubview(makeGlassButton(title: label, id: ch, isSpecial: false, tag: rowOffset + idx))
      }
    }
    
    container.addSubview(stack)
    
    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
    ])
    
    return container
  }

  func makeEqualRow(keys: [String], rowOffset: Int = 0) -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 5
    for (idx, key) in keys.enumerated() {
      stack.addArrangedSubview(makeGlassButton(title: key, id: key, isSpecial: false, tag: rowOffset + idx))
    }
    return stack
  }

  func makeShiftRow(middleKeys: [String], keyValues: [String], rowOffset: Int) -> UIView {
    let container = UIView()
    container.clipsToBounds = false // 가장자리 애니메이션 잘림 방지
    
    // 이 시점에 이미 isSymbol 상태가 반영되어 있으므로 여기서도 체크 필요
    let shiftTitle: String
    let fontSize: CGFloat
    if isSymbol {
      shiftTitle = isShifted ? "2/2" : "1/2"
      fontSize = 16
    } else {
      shiftTitle = isShiftLocked ? "⇪" : "⇧"
      fontSize = KeyboardConstants.KEY_FONT_SIZE
    }
    
    let shiftBtn = makeGlassButton(title: shiftTitle, id: "shift", isSpecial: true, tag: 699, fontSize: fontSize)
    shiftBtn.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
    
    // 시프트 롱 프레스 추가 (0.5초)
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleShiftLongPress(_:)))
    longPress.minimumPressDuration = 0.5
    shiftBtn.addGestureRecognizer(longPress)
    
    if isShifted {
       if isShiftLocked {
         shiftBtn.backgroundColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.8) : UIColor(white: 0.0, alpha: 0.7)
         shiftBtn.setTitleColor(isDarkMode ? .black : .white, for: .normal)
       } else {
         shiftBtn.backgroundColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.4) : UIColor(white: 0.0, alpha: 0.3)
         shiftBtn.setTitleColor(.white, for: .normal)
       }
    }
    shiftButton = shiftBtn

    let bsBtn = makeGlassButton(title: "⌫", id: "backspace", isSpecial: true, tag: 698)
    bsBtn.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
    bsBtn.addTarget(self, action: #selector(backspaceTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

    let letterStack = UIStackView()
    letterStack.axis = .horizontal; letterStack.distribution = .fillEqually; letterStack.spacing = 5
    for (idx, (label, value)) in zip(middleKeys, keyValues).enumerated() {
      letterStack.addArrangedSubview(makeGlassButton(title: label, id: value, isSpecial: false, tag: rowOffset + idx))
    }

    [shiftBtn, letterStack, bsBtn].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; container.addSubview($0) }
    NSLayoutConstraint.activate([
      shiftBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor), shiftBtn.topAnchor.constraint(equalTo: container.topAnchor),
      shiftBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor), shiftBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.15),
      letterStack.leadingAnchor.constraint(equalTo: shiftBtn.trailingAnchor, constant: 5), letterStack.trailingAnchor.constraint(equalTo: bsBtn.leadingAnchor, constant: -5),
      letterStack.topAnchor.constraint(equalTo: container.topAnchor), letterStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      bsBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor), bsBtn.topAnchor.constraint(equalTo: container.topAnchor),
      bsBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor), bsBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.15)
    ])
    return container
  }

  func updateKeyLabels() {
    let row1Normal: [Character] = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    let row2Normal: [Character] = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    let row3Normal: [Character] = ["z", "x", "c", "v", "b", "n", "m"]

    for btn in allKeyButtons {
      switch btn.tag {
      case 201: btn.setTitle(isSymbol ? (isHangul ? "한글" : "ENG") : "♥︎", for: .normal)
      case 202: btn.setTitle(isHangul ? "ENG" : "한글", for: .normal)
      case 400...409:
        let idx = btn.tag - 400
        if isSymbol {
          let keys = isShifted ? KeyboardConstants.SYM_ROW1_SHIFTED : KeyboardConstants.SYM_ROW1_NORMAL
          btn.setTitle(keys[idx], for: .normal); btn.keyValue = keys[idx]
        } else {
          let ch = row1Normal[idx]
          btn.setTitle(letterLabel(for: ch), for: .normal); btn.keyValue = String(ch)
        }
      case 500...509:
        let idx = btn.tag - 500
        if isSymbol {
          let keys = isShifted ? KeyboardConstants.SYM_ROW2_SHIFTED : KeyboardConstants.SYM_ROW2_NORMAL
          btn.setTitle(keys[idx], for: .normal); btn.keyValue = keys[idx]
        } else {
          let ch = row2Normal[idx]
          btn.setTitle(letterLabel(for: ch), for: .normal); btn.keyValue = String(ch)
        }
      case 600...606:
        let idx = btn.tag - 600
        if isSymbol {
          let keys = isShifted ? KeyboardConstants.SYM_ROW3_SHIFTED : KeyboardConstants.SYM_ROW3_NORMAL
          btn.setTitle(keys[idx], for: .normal); btn.keyValue = keys[idx]
        } else {
          let ch = row3Normal[idx]
          btn.setTitle(letterLabel(for: ch), for: .normal); btn.keyValue = String(ch)
        }
      case 699:
        btn.setTitle(isShiftLocked ? "⇪" : "⇧", for: .normal)
        if isShifted {
          btn.backgroundColor = isShiftLocked ? (isDarkMode ? UIColor(white: 1.0, alpha: 0.8) : UIColor(white: 0.0, alpha: 0.7)) : (isDarkMode ? UIColor(white: 1.0, alpha: 0.4) : UIColor(white: 0.0, alpha: 0.3))
          btn.setTitleColor(isShiftLocked ? (isDarkMode ? .black : .white) : .white, for: .normal)
        } else {
          btn.backgroundColor = specialGlassColor; btn.setTitleColor(specialTextColor, for: .normal)
        }
      default: break
      }
    }
  }
}

