import UIKit

extension KeyboardViewController {

  // MARK: - 레이아웃 빌드

  func buildKeyboard() {
    resetTransientInputState()
    // 이모지 변형 팝업은 키보드 컨테이너의 형제 뷰이므로 일반 subview 제거 전에 정리한다.
    customKeyboardView?.removeFromSuperview()
    for subview in view.subviews {
      subview.removeFromSuperview()
    }
    utilityRow = nil
    bottomRow = nil
    mainContentStack = nil
    customKeyboardView = nil
    allKeyButtons.removeAll()
    shiftButton = nil
    spaceButton = nil
    nextKeyboardButton = nil

    // 1. 바톰 행 (하단 고정)
    let botRow = makeBottomRow()
    botRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(botRow)
    bottomRow = botRow

    NSLayoutConstraint.activate([
      botRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
      botRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      botRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      botRow.heightAnchor.constraint(equalToConstant: layoutMetrics.bottomRowH),
    ])
    botRow.setContentHuggingPriority(.required, for: .vertical)
    botRow.setContentCompressionResistancePriority(.required, for: .vertical)

    // 2. 메인 콘텐츠 스택 (botRow 위로 쌓기)
    let contentStack = setupMainContentStack(above: botRow)

    // 3. 유틸리티 행 (contentStack 위로 쌓기)
    let utilRow = makeUtilityRow()
    utilRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(utilRow)
    utilityRow = utilRow

    NSLayoutConstraint.activate([
      utilRow.bottomAnchor.constraint(equalTo: contentStack.topAnchor, constant: -7),
      utilRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      utilRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      utilRow.heightAnchor.constraint(equalToConstant: layoutMetrics.utilRowH),
    ])
    utilRow.setContentHuggingPriority(.required, for: .vertical)
    utilRow.setContentCompressionResistancePriority(.required, for: .vertical)

    // 4. 유틸리티 행 상단을 view 상단에 고정 (required)
    //    이 제약으로 세로 레이아웃 체인이 view의 top~bottom까지 모두 연결되어,
    //    확정된 키보드 높이에 맞춰 메인 콘텐츠 스택이 행 비율대로 채워진다.
    utilRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 6).isActive = true

    // 5. 시작 가시성 적용
    updatePanelVisibility()
    lastRenderedPanel = interactionState.panel
  }

  /// 키보드 뷰에 확정 높이 제약을 설치/갱신한다.
  /// 첫 활성화는 viewWillAppear에서 하고, 이후에는 콘텐츠 재구성보다 먼저 높이를 바꾼다.
  func installKeyboardHeightConstraint() {
    let targetHeight = desiredKeyboardHeight
    if let c = keyboardHeightConstraint {
      if abs(c.constant - targetHeight) > 0.5 {
        c.constant = targetHeight
      }
      if !c.isActive { c.isActive = true }
    } else {
      let c = view.heightAnchor.constraint(equalToConstant: targetHeight)
      c.identifier = "CustomKeyboard.height"
      // 시스템의 전환용 임시 높이 제약보다 한 단계 낮춰 콘솔 충돌과 강제 제약 파기를 피한다.
      c.priority = UILayoutPriority(999)
      c.isActive = true
      keyboardHeightConstraint = c
    }
  }

  private func updatePanelVisibility() {
    guard let bot = bottomRow else { return }

    if isCustom {
      // 1. 커스텀 뷰 생성 (빈 패널 방지)
      if customKeyboardView == nil {
        setupCustomPanel(above: bot)
      }
      customKeyboardView?.isHidden = false

      // 2. 메인 스택 숨김
      mainContentStack?.isHidden = true
    } else {
      // 1. 메인 스택 표시
      mainContentStack?.isHidden = false

      // 2. 이모지 패널 등 무거운 요소 메모리 해제
      removeCustomPanel(resetMode: false)
    }
  }

  /// 이모지 패널과 외부에 떠 있는 변형 팝업을 함께 제거하고 기본 키 행을 복구한다.
  func removeCustomPanel(resetMode: Bool = true) {
    customKeyboardView?.prepareForRemoval()
    customKeyboardView?.removeFromSuperview()
    customKeyboardView = nil
    mainContentStack?.isHidden = false
    if resetMode {
      interactionState.leaveEmojiPanel()
      lastRenderedPanel = interactionState.panel
    }
  }

  private func setupCustomPanel(above botRow: UIView) {
    let customView = CustomKeyboardView(palette: themePalette)
    customView.delegate = self
    customView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(customView)
    self.customKeyboardView = customView

    // 메인 콘텐츠 스택과 동일하게 유틸 행~바텀 행 사이를 가득 채운다 (높이 고정 안 함).
    var constraints: [NSLayoutConstraint] = [
      customView.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
      customView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      customView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
    ]
    if let utilRow = utilityRow {
      constraints.append(
        customView.topAnchor.constraint(equalTo: utilRow.bottomAnchor, constant: 7))
    }
    NSLayoutConstraint.activate(constraints)
  }

  private func setupMainContentStack(above botRow: UIView) -> UIStackView {
    if let existing = mainContentStack { return existing }

    let contentStack = ExpandedHitStackView()
    contentStack.axis = .vertical
    contentStack.distribution = .fill
    contentStack.spacing = 5
    contentStack.hitTestInsets = UIEdgeInsets(
      top: -KeyboardConstants.Interaction.sectionHalfSpacing,
      left: -KeyboardConstants.Interaction.horizontalHitSlop,
      bottom: -KeyboardConstants.Interaction.sectionHalfSpacing,
      right: -KeyboardConstants.Interaction.horizontalHitSlop
    )
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    contentStack.clipsToBounds = false  // 자식들의 확장된 터치 영역 허용
    view.addSubview(contentStack)
    self.mainContentStack = contentStack

    // 높이를 고정하지 않는다. top은 유틸 행 아래(buildKeyboard의 utilRow.bottom 제약),
    // bottom은 바텀 행 위에 핀 고정되므로, 키보드 전체 높이에서 남는 공간을 이 스택이 흡수한다.
    NSLayoutConstraint.activate([
      contentStack.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
      contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
    ])

    let numRow = makeNumberRow()
    contentStack.addArrangedSubview(numRow)

    let keyRows: [UIView]
    if isSymbol {
      let rows =
        isShifted
        ? [
          KeyboardConstants.shiftedSymbolRow1, KeyboardConstants.shiftedSymbolRow2,
          KeyboardConstants.shiftedSymbolRow3,
        ]
        : [
          KeyboardConstants.symbolRow1, KeyboardConstants.symbolRow2,
          KeyboardConstants.symbolRow3,
        ]

      let v1 = makeEqualRow(keys: rows[0], rowOffset: 400)
      let v2 = makeLetterRowStack(rows[1], rowOffset: 500)  // 9키 대응 로직 사용
      let v3 = makeShiftRow(middleKeys: rows[2], keyValues: rows[2], rowOffset: 600)  // 7키 대응 로직 사용
      keyRows = [v1, v2, v3]
    } else {
      keyRows = [makeLetterRow1(), makeLetterRow2(), makeLetterShiftRow()]
    }
    for row in keyRows {
      contentStack.addArrangedSubview(row)
    }

    // 행 높이를 절대값이 아닌 '비율'로 묶는다. 키 행 3개는 서로 같고, 숫자 행은 키 행 대비
    // 38/42 비율. 스택이 시스템 높이에 맞춰 늘어나면 모든 행이 비례 확대/축소된다.
    let baseRow = keyRows[0]
    for row in keyRows.dropFirst() {
      row.heightAnchor.constraint(equalTo: baseRow.heightAnchor).isActive = true
    }
    numRow.heightAnchor.constraint(
      equalTo: baseRow.heightAnchor,
      multiplier: layoutMetrics.numberRowH / layoutMetrics.mainKeyH
    ).isActive = true

    // 행이 스택 높이에 맞춰 늘어나도록 hugging은 낮게, 압축 저항은 시스템 높이에는 양보하도록 설정
    for row in [numRow] + keyRows {
      row.setContentHuggingPriority(.defaultLow, for: .vertical)
      row.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    }

    return contentStack
  }

  // MARK: - 요소 생성

  func makeUtilityRow() -> UIView {
    let stack = ExpandedHitStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 5
    stack.hitTestInsets = UIEdgeInsets(
      top: -KeyboardConstants.Interaction.keyboardEdgeSpacing,
      left: -KeyboardConstants.Interaction.horizontalHitSlop,
      bottom: -KeyboardConstants.Interaction.sectionHalfSpacing,
      right: -KeyboardConstants.Interaction.horizontalHitSlop
    )
    stack.clipsToBounds = false

    let cursors: [(CursorIconType, String)] = [
      (.lineStart, KeyboardConstants.KeyID.cursorLineStart),
      (.left, KeyboardConstants.KeyID.cursorLeft),
      (.right, KeyboardConstants.KeyID.cursorRight),
      (.lineEnd, KeyboardConstants.KeyID.cursorLineEnd),
    ]

    for (type, id) in cursors {
      let btn = makeGlassButton(title: "", id: id, isSpecial: true)
      let img = drawCursorImage(type: type, size: CGSize(width: 32, height: 32))
      btn.setImage(img.withRenderingMode(.alwaysTemplate), for: .normal)
      btn.tintColor = specialTextColor

      // 가속 및 스마트 이동을 위한 핸들러 연결
      btn.accessibilityIdentifier = id
      btn.accessibilityLabel = cursorAccessibilityLabel(for: type)
      btn.addTarget(self, action: #selector(cursorTouchDown(_:)), for: .touchDown)
      btn.addTarget(
        self, action: #selector(cursorTouchUp(_:)),
        for: [.touchUpInside, .touchUpOutside, .touchCancel])

      stack.addArrangedSubview(btn)
      stack.registerKey(btn)
    }

    let customBtn = makeGlassButton(
      title: "☺︎", id: KeyboardConstants.KeyID.custom, isSpecial: true, fontSize: 26)
    customBtn.accessibilityLabel = "이모지"
    if isCustom { customBtn.backgroundColor = activeGlassColor }
    customBtn.addTarget(self, action: #selector(customTapped), for: .touchUpInside)
    stack.addArrangedSubview(customBtn)
    stack.registerKey(customBtn)

    let nextKeyboardBtn = makeGlassButton(
      title: "", id: KeyboardConstants.KeyID.nextKeyboard, isSpecial: true)
    let globeConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
    if let image = UIImage(systemName: "globe", withConfiguration: globeConfig) {
      nextKeyboardBtn.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
      nextKeyboardBtn.tintColor = specialTextColor
    }
    nextKeyboardBtn.accessibilityLabel = "다음 키보드"
    nextKeyboardBtn.acceptsGapHitRouting = false
    nextKeyboardBtn.addTarget(
      self, action: #selector(nextKeyboardTapped), for: .touchUpInside)
    nextKeyboardBtn.isHidden = !needsInputModeSwitchKey
    nextKeyboardButton = nextKeyboardBtn
    stack.addArrangedSubview(nextKeyboardBtn)
    stack.registerKey(nextKeyboardBtn)

    let dismissBtn = makeGlassButton(
      title: "", id: KeyboardConstants.KeyID.dismiss, isSpecial: true)
    let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
    if let img = UIImage(systemName: "keyboard.chevron.compact.down", withConfiguration: config) {
      dismissBtn.setImage(img.withRenderingMode(.alwaysTemplate), for: .normal)
      dismissBtn.tintColor = specialTextColor
    }
    dismissBtn.accessibilityLabel = "키보드 닫기"
    dismissBtn.acceptsGapHitRouting = false
    dismissBtn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    stack.addArrangedSubview(dismissBtn)
    stack.registerKey(dismissBtn)

    // 최상단 유틸 버튼(커서/이모지/키보드 닫기)은 일반 키보다 모서리를 살짝 더 각지게
    let utilRadius = layoutMetrics.utilCornerRadius
    for case let btn as KeyButton in stack.arrangedSubviews {
      btn.layer.cornerRadius = utilRadius
    }

    return stack
  }

  private func cursorAccessibilityLabel(for type: CursorIconType) -> String {
    switch type {
    case .lineStart: "줄 처음으로 이동"
    case .left: "커서 왼쪽 이동"
    case .right: "커서 오른쪽 이동"
    case .lineEnd: "줄 끝으로 이동"
    }
  }

  func makeBottomRow() -> UIView {
    let container = ExpandedHitView()
    container.hitTestInsets = UIEdgeInsets(
      top: -KeyboardConstants.Interaction.sectionHalfSpacing,
      left: -KeyboardConstants.Interaction.horizontalHitSlop,
      bottom: -KeyboardConstants.Interaction.keyboardEdgeSpacing,
      right: -KeyboardConstants.Interaction.horizontalHitSlop
    )
    container.clipsToBounds = false  // 가장자리 터치 및 애니메이션 잘림 방지
    let symBtnTitle = isSymbol ? (isHangul ? "한글" : "ENG") : "♥︎"
    let symBtn = makeGlassButton(
      title: symBtnTitle, id: KeyboardConstants.KeyID.symbol, isSpecial: true, tag: 201,
      fontSize: 16)
    symBtn.accessibilityLabel = "기호 키보드"
    symBtn.addTarget(self, action: #selector(symbolTapped), for: .touchUpInside)

    let langBtn = makeGlassButton(
      title: isHangul ? "ENG" : "한글", id: KeyboardConstants.KeyID.language, isSpecial: true,
      tag: 202, fontSize: 16)
    langBtn.accessibilityLabel = "한글 영문 전환"
    langBtn.addTarget(self, action: #selector(langTapped), for: .touchUpInside)

    let enterBtn = makeGlassButton(
      title: "↵", id: KeyboardConstants.KeyID.enter, isSpecial: true, tag: 205)
    enterBtn.accessibilityLabel = "줄바꿈"
    enterBtn.addTarget(self, action: #selector(enterTapped), for: .touchUpInside)

    let spaceBtn = makeGlassButton(
      title: "", id: KeyboardConstants.KeyID.space, isSpecial: false, tag: 203)
    spaceBtn.accessibilityLabel = "스페이스"
    // 커서 모드 억제 플래그는 한 번의 스페이스 터치를 추적하므로 같은 키의 다중 터치는 받지 않는다.
    spaceBtn.isMultipleTouchEnabled = false
    spaceButton = spaceBtn
    let dotBtn = makeGlassButton(title: ".", id: ".", isSpecial: false, tag: 204)

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSpacePan(_:)))
    pan.delaysTouchesBegan = false
    pan.cancelsTouchesInView = false
    pan.delegate = self
    spaceBtn.addGestureRecognizer(pan)

    // 꾹 누르면(롱프레스) 드래그 없이도 커서 이동 모드로 진입.
    // 롱프레스가 인식된 뒤에도 pan이 동시 인식되어야 드래그로 커서가 움직인다(delegate).
    let spaceLongPress = UILongPressGestureRecognizer(
      target: self, action: #selector(handleSpaceLongPress(_:)))
    spaceLongPress.minimumPressDuration = KeyboardConstants.Interaction.spaceLongPressDuration
    spaceLongPress.cancelsTouchesInView = false
    spaceLongPress.delegate = self
    spaceBtn.addGestureRecognizer(spaceLongPress)

    for button in [symBtn, langBtn, spaceBtn, dotBtn, enterBtn] {
      button.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(button)
      container.registerKey(button)
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
      spaceBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    return container
  }

  // MARK: - 스페이스바 드래그 비주얼

  /// 스페이스바 드래그(커서 이동) 시작: 스페이스바를 눌린 강조 상태로 고정하고,
  /// 나머지 키 위에 딤 오버레이를 깔아 입력 불가 + 드래그 중임을 알린다.
  func beginSpaceDragVisual() {
    guard let space = spaceButton, spaceDragOverlay == nil else { return }

    // 1. 스페이스바를 눌린 강조 상태로 고정 + 커서 이동 힌트(‹ ›) 표시
    space.dragActiveColor = activeGlassColor
    space.dragActive = true
    space.setTitle("‹    ›", for: .normal)
    space.setTitleColor(activeTextColor, for: .normal)

    // 2. 스페이스바를 제외한 영역을 덮는 딤 오버레이
    let spaceFrame = space.convert(space.bounds, to: view)
    let holeRect = spaceFrame.insetBy(dx: -1, dy: -1)
    let radius = space.layer.cornerRadius

    let overlay = SpaceDragOverlayView(frame: view.bounds)
    overlay.passthroughRect = spaceFrame
    overlay.backgroundColor = .clear

    // 딤: 전체를 칠하되 스페이스바 영역만 구멍을 뚫는다 (even-odd)
    let dim = CAShapeLayer()
    let dimPath = UIBezierPath(rect: overlay.bounds)
    dimPath.append(UIBezierPath(roundedRect: holeRect, cornerRadius: radius))
    dim.path = dimPath.cgPath
    dim.fillRule = .evenOdd
    dim.fillColor = themePalette.dragOverlay.cgColor
    overlay.layer.addSublayer(dim)

    // 스페이스바 강조 링 (드래그 중인 컨트롤을 또렷이)
    let ring = CAShapeLayer()
    ring.path = UIBezierPath(roundedRect: holeRect, cornerRadius: radius).cgPath
    ring.fillColor = UIColor.clear.cgColor
    ring.strokeColor = themePalette.dragRing.cgColor
    ring.lineWidth = 1.5
    overlay.layer.addSublayer(ring)

    view.addSubview(overlay)
    spaceDragOverlay = overlay

    overlay.alpha = 0
    UIView.animate(withDuration: 0.15) { overlay.alpha = 1 }
  }

  /// 스페이스바 드래그 종료: 강조 상태와 오버레이를 해제한다.
  func endSpaceDragVisual() {
    if let space = spaceButton {
      space.dragActive = false
      space.dragActiveColor = nil
      space.setTitle("", for: .normal)
    }

    guard let overlay = spaceDragOverlay else { return }
    spaceDragOverlay = nil
    // 페이드아웃 중인 0.15초 동안 다음 키 입력을 가로채지 않도록 즉시 비활성화한다.
    overlay.isUserInteractionEnabled = false
    UIView.animate(
      withDuration: 0.15,
      animations: {
        overlay.alpha = 0
      },
      completion: { _ in
        overlay.removeFromSuperview()
      })
  }

  // MARK: - 버튼 팩토리

  func makeGlassButton(
    title: String, id: String, isSpecial: Bool, tag: Int = 0, fontSize: CGFloat? = nil
  ) -> KeyButton {
    let btn = KeyButton(type: .custom)
    btn.applyGlassPalette(themePalette)
    btn.tag = tag
    btn.keyValue = id
    btn.setTitle(title, for: .normal)
    btn.titleLabel?.font = UIFont.systemFont(
      ofSize: fontSize ?? layoutMetrics.keyFontSize, weight: isSpecial ? .medium : .regular)
    btn.setTitleColor(isSpecial ? specialTextColor : keyTextColor, for: .normal)
    btn.backgroundColor = isSpecial ? specialGlassColor : keyGlassColor
    btn.normalBackgroundColor = btn.backgroundColor

    btn.layer.cornerRadius = layoutMetrics.cornerRadius
    // 단색 보더 대신 KeyButton의 림 라이트로 가장자리를 표현 (글래스 느낌)
    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOffset = CGSize(width: 0, height: 3)
    btn.layer.shadowOpacity = 0.30
    btn.layer.shadowRadius = 6
    btn.isExclusiveTouch = false
    btn.accessibilityTraits.insert(.keyboardKey)
    btn.touchDelegate = self
    btn.accessibilityActivationHandler = { [weak self, weak btn] in
      guard let self, let btn, let action = self.keyboardAction(for: btn.keyValue) else {
        return false
      }
      let didPerform = self.dispatchKeyboardAction(action)
      if didPerform, case .character = action {
        btn.committedInputGeneration = self.inputMutationGeneration
      }
      return didPerform
    }

    // 숫자·기호처럼 변체가 없는 키에는 롱프레스 인식기를 만들지 않는다. 모든 일반 키에
    // 인식기를 붙이면 화면 가장자리 키에서도 불필요한 제스처 중재 비용이 발생한다.
    if supportsVariantLongPress(keyValue: id) {
      let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      lp.minimumPressDuration = KeyboardConstants.Interaction.variantLongPressDuration
      // 변체 팝업 인식이 일반 문자 터치를 취소하면 빠른 입력 중 키업 상태가 꼬일 수 있다.
      lp.cancelsTouchesInView = false
      lp.delaysTouchesBegan = false
      btn.addGestureRecognizer(lp)
    }

    allKeyButtons.append(btn)
    return btn
  }

  private func supportsVariantLongPress(keyValue: String) -> Bool {
    guard keyValue.count == 1, let character = keyValue.first else { return false }
    // 물리 QWERTY 문자 키는 한글에서는 겹자모, 영문에서는 대소문자 변체가 될 수 있다.
    return KeyboardConstants.hangulMap[character] != nil
  }

  func makeDummyButton() -> KeyButton {
    let btn = makeGlassButton(
      title: "", id: KeyboardConstants.KeyID.dummy, isSpecial: true)
    btn.isUserInteractionEnabled = false  // 터치 방지
    btn.alpha = 0
    return btn
  }

  // MARK: - 외관 업데이트

  func rebuildKeyboard() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    if interactionState.panel != lastRenderedPanel {
      updatePanelVisibility()
      lastRenderedPanel = interactionState.panel
    }

    // 외관 및 레이블은 패널 전환 여부와 무관하게 항상 업데이트
    updateKeyLabels()
    updateAppearance()

    CATransaction.commit()
  }

  func updateAppearance() {
    CATransaction.begin()
    CATransaction.setDisableActions(true)

    for btn in allKeyButtons {
      let id = btn.keyValue
      let isSpecial = KeyboardConstants.KeyID.specialKeys.contains(id)
        || KeyboardConstants.KeyID.cursorKeys.contains(id)

      if id == KeyboardConstants.KeyID.shift {
        let isActive = isShifted || isShiftLocked
        let targetColor = isActive ? activeGlassColor : specialGlassColor
        let targetTextC = isActive ? activeTextColor : specialTextColor

        if btn.backgroundColor != targetColor {
          btn.backgroundColor = targetColor
          btn.normalBackgroundColor = btn.backgroundColor
        }

        if btn.titleColor(for: .normal) != targetTextC {
          btn.setTitleColor(targetTextC, for: .normal)
          btn.tintColor = targetTextC
        }
        btn.accessibilityTraits = [.keyboardKey]
        if isActive { btn.accessibilityTraits.insert(.selected) }
        btn.accessibilityLabel = isSymbol ? "기호 페이지" : "시프트"
        btn.accessibilityValue =
          isSymbol
          ? (isShifted ? "2/2" : "1/2")
          : (isShiftLocked ? "고정" : (isActive ? "한 번 사용" : "꺼짐"))

        let targetTitle = isSymbol ? (isShifted ? "2/2" : "1/2") : (isShiftLocked ? "⇪" : "⇧")
        if btn.title(for: .normal) != targetTitle {
          btn.setTitle(targetTitle, for: .normal)
          btn.titleLabel?.font = UIFont.systemFont(
            ofSize: isSymbol ? 16 : layoutMetrics.keyFontSize, weight: .medium)
        }
      }

      if id != KeyboardConstants.KeyID.shift {
        let isCustomActive = id == KeyboardConstants.KeyID.custom && isCustom
        let targetColor = isCustomActive
          ? activeGlassColor : (isSpecial ? specialGlassColor : keyGlassColor)
        if btn.backgroundColor != targetColor {
          btn.backgroundColor = targetColor
          btn.normalBackgroundColor = btn.backgroundColor
        }

        let targetTextColor = isCustomActive
          ? activeTextColor : (isSpecial ? specialTextColor : keyTextColor)
        if btn.titleColor(for: .normal) != targetTextColor {
          btn.setTitleColor(targetTextColor, for: .normal)
          btn.tintColor = targetTextColor
        }
        btn.accessibilityTraits = [.keyboardKey]
        if isCustomActive { btn.accessibilityTraits.insert(.selected) }
        if id == KeyboardConstants.KeyID.custom {
          btn.accessibilityValue = isCustomActive ? "선택됨" : "선택 안 됨"
        }
      }

      btn.layer.shadowOpacity = 0.30
      btn.layer.shadowRadius = 6

      // 글래스 레이어(바디 광택 + 림 라이트) 업데이트 (중앙 집중식 관리)
      btn.applyGlassPalette(themePalette)
    }

    CATransaction.commit()
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
    let container = ExpandedHitView()
    container.clipsToBounds = false
    let stack = ExpandedHitStackView()
    stack.axis = .horizontal
    stack.distribution = .fill
    stack.spacing = 3
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.clipsToBounds = false

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
        stack.registerKey(key)
        container.registerKey(key)

        if let first = firstKey {
          key.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true
        } else {
          firstKey = key
        }
      }

      stack.addArrangedSubview(rightDummy)

      if let key = firstKey {
        // 양옆 공백(더미)을 키 폭의 0.4배로 — 0.3 대비 살짝 넓혀 9키 행 버튼을 조금 좁힌다
        leftDummy.widthAnchor.constraint(equalTo: key.widthAnchor, multiplier: 0.4).isActive = true
        rightDummy.widthAnchor.constraint(equalTo: key.widthAnchor, multiplier: 0.4).isActive = true
      }
    } else {
      // 10개 버튼일 경우 (기존 fillEqually와 동일하게 동작)
      stack.distribution = .fillEqually
      for (idx, ch) in chars.enumerated() {
        let label = isSymbol ? ch : (ch.count == 1 ? letterLabel(for: Character(ch)) : ch)
        let key = makeGlassButton(title: label, id: ch, isSpecial: false, tag: rowOffset + idx)
        stack.addArrangedSubview(key)
        stack.registerKey(key)
        container.registerKey(key)
      }
    }

    container.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.topAnchor.constraint(equalTo: container.topAnchor),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
    ])

    return container
  }

  func makeEqualRow(keys: [String], rowOffset: Int = 0) -> UIView {
    let stack = ExpandedHitStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 3
    stack.clipsToBounds = false
    for (idx, key) in keys.enumerated() {
      let button = makeGlassButton(title: key, id: key, isSpecial: false, tag: rowOffset + idx)
      stack.addArrangedSubview(button)
      stack.registerKey(button)
    }
    return stack
  }

  func makeShiftRow(middleKeys: [String], keyValues: [String], rowOffset: Int) -> UIView {
    let container = ExpandedHitView()
    container.clipsToBounds = false  // 가장자리 애니메이션 잘림 방지

    // 이 시점에 이미 isSymbol 상태가 반영되어 있으므로 여기서도 체크 필요
    let shiftTitle: String
    let fontSize: CGFloat
    if isSymbol {
      shiftTitle = isShifted ? "2/2" : "1/2"
      fontSize = 16
    } else {
      shiftTitle = isShiftLocked ? "⇪" : "⇧"
      fontSize = layoutMetrics.keyFontSize
    }

    let shiftBtn = makeGlassButton(
      title: shiftTitle, id: KeyboardConstants.KeyID.shift, isSpecial: true, tag: 699,
      fontSize: fontSize)
    shiftBtn.accessibilityLabel = "시프트"
    shiftBtn.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)

    // 시프트 롱 프레스 추가 (0.5초)
    let longPress = UILongPressGestureRecognizer(
      target: self, action: #selector(handleShiftLongPress(_:)))
    longPress.minimumPressDuration = KeyboardConstants.Interaction.shiftLongPressDuration
    shiftBtn.addGestureRecognizer(longPress)

    shiftButton = shiftBtn

    let bsBtn = makeGlassButton(
      title: "⌫", id: KeyboardConstants.KeyID.backspace, isSpecial: true, tag: 698)
    bsBtn.accessibilityLabel = "삭제"
    bsBtn.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
    bsBtn.addTarget(
      self, action: #selector(backspaceTouchUp(_:)),
      for: [.touchUpInside, .touchUpOutside, .touchCancel])

    let letterStack = UIStackView()
    letterStack.axis = .horizontal
    letterStack.distribution = .fillEqually
    letterStack.spacing = 3
    for (idx, (label, value)) in zip(middleKeys, keyValues).enumerated() {
      letterStack.addArrangedSubview(
        makeGlassButton(title: label, id: value, isSpecial: false, tag: rowOffset + idx))
    }

    for view in [shiftBtn, letterStack, bsBtn] {
      view.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(view)
    }

    let letterKeys = letterStack.arrangedSubviews.compactMap { $0 as? KeyButton }
    for key in [shiftBtn] + letterKeys + [bsBtn] {
      container.registerKey(key)
    }
    NSLayoutConstraint.activate([
      shiftBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      shiftBtn.topAnchor.constraint(equalTo: container.topAnchor),
      shiftBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      letterStack.leadingAnchor.constraint(equalTo: shiftBtn.trailingAnchor, constant: 3),
      letterStack.trailingAnchor.constraint(equalTo: bsBtn.leadingAnchor, constant: -3),
      letterStack.topAnchor.constraint(equalTo: container.topAnchor),
      letterStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      bsBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      bsBtn.topAnchor.constraint(equalTo: container.topAnchor),
      bsBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
    // ⇧/⌫ 폭을 글자 키의 1.5배로 고정 → 표준 10열 그리드에 맞아 글자 키 폭이 다른 행과 거의 동일해진다.
    if let letterKey = letterKeys.first {
      NSLayoutConstraint.activate([
        shiftBtn.widthAnchor.constraint(equalTo: letterKey.widthAnchor, multiplier: 1.5),
        bsBtn.widthAnchor.constraint(equalTo: letterKey.widthAnchor, multiplier: 1.5),
      ])
    }
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
          let keys =
            isShifted ? KeyboardConstants.shiftedSymbolRow1 : KeyboardConstants.symbolRow1
          let target = keys[idx]
          if btn.title(for: .normal) != target {
            btn.setTitle(target, for: .normal)
            btn.keyValue = target
          }
        } else {
          let ch = row1Normal[idx]
          let target = letterLabel(for: ch)
          if btn.title(for: .normal) != target {
            btn.setTitle(target, for: .normal)
            btn.keyValue = String(ch)
          }
        }
      case 500...509:
        let idx = btn.tag - 500
        if isSymbol {
          let keys =
            isShifted ? KeyboardConstants.shiftedSymbolRow2 : KeyboardConstants.symbolRow2
          let target = keys[idx]
          if btn.title(for: .normal) != target {
            btn.setTitle(target, for: .normal)
            btn.keyValue = target
          }
        } else {
          let ch = row2Normal[idx]
          let target = letterLabel(for: ch)
          if btn.title(for: .normal) != target {
            btn.setTitle(target, for: .normal)
            btn.keyValue = String(ch)
          }
        }
      case 600...606:
        let idx = btn.tag - 600
        if isSymbol {
          let keys =
            isShifted ? KeyboardConstants.shiftedSymbolRow3 : KeyboardConstants.symbolRow3
          let target = keys[idx]
          if btn.title(for: .normal) != target {
            btn.setTitle(target, for: .normal)
            btn.keyValue = target
          }
        } else {
          let ch = row3Normal[idx]
          let target = letterLabel(for: ch)
          if btn.title(for: .normal) != target {
            btn.setTitle(target, for: .normal)
            btn.keyValue = String(ch)
          }
        }
      case 699:
        let targetTitle = isShiftLocked ? "⇪" : "⇧"
        if btn.title(for: .normal) != targetTitle {
          btn.setTitle(targetTitle, for: .normal)
        }
      default: break
      }
    }
  }
}
