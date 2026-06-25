import UIKit

extension KeyboardViewController {
  
  // MARK: - 레이아웃 빌드
  
  func buildKeyboard() {
    view.subviews.forEach { $0.removeFromSuperview() }
    utilityRow = nil
    bottomRow = nil
    mainContentStack = nil
    customKeyboardView = nil
    allKeyButtons.removeAll()
    shiftButton = nil
    spaceButton = nil
    
    // 1. 바톰 행 (하단 고정)
    let botRow = makeBottomRow()
    botRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(botRow)
    bottomRow = botRow

    NSLayoutConstraint.activate([
      botRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
      botRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      botRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      botRow.heightAnchor.constraint(equalToConstant: layoutMetrics.bottomRowH)
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
      utilRow.heightAnchor.constraint(equalToConstant: layoutMetrics.utilRowH)
    ])
    utilRow.setContentHuggingPriority(.required, for: .vertical)
    utilRow.setContentCompressionResistancePriority(.required, for: .vertical)

    // 4. 유틸리티 행 상단을 view 상단에 고정 (required)
    //    이 제약으로 세로 레이아웃 체인이 view의 top~bottom까지 모두 연결되어,
    //    확정된 키보드 높이에 맞춰 메인 콘텐츠 스택이 행 비율대로 채워진다.
    utilRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 6).isActive = true

    // 5. 시작 가시성 적용
    updatePanelVisibility()
  }

  /// 키보드 뷰에 확정 높이 제약을 설치/갱신한다.
  /// viewWillAppear에서 매 등장마다 호출해야 한다. viewDidLoad 시점에 걸면 시스템이
  /// 등장 애니메이션을 '잠정 높이'로 시작한 뒤 보정하므로 높이가 튄다. 등장 직전에
  /// 걸어야 시스템이 애니메이션 시작 전에 정확한 높이를 읽는다.
  func installKeyboardHeightConstraint() {
    if let c = keyboardHeightConstraint {
      c.constant = desiredKeyboardHeight
      c.isActive = true
    } else {
      let c = view.heightAnchor.constraint(equalToConstant: desiredKeyboardHeight)
      // 시스템이 inputView에 거는 높이 제약과 충돌해 등장/전환 시 레이아웃이 꼬이는 것을
      // 막기 위해 required(1000)가 아닌 999로 건다. (Apple 권장)
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
      if let existingCustom = customKeyboardView {
        existingCustom.removeFromSuperview()
        customKeyboardView = nil
      }
    }
  }

  private func setupCustomPanel(above botRow: UIView) {
    let customView = CustomKeyboardView(isDarkMode: isDarkMode)
    customView.delegate = self
    customView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(customView)
    self.customKeyboardView = customView

    // 메인 콘텐츠 스택과 동일하게 유틸 행~바텀 행 사이를 가득 채운다 (높이 고정 안 함).
    var constraints: [NSLayoutConstraint] = [
      customView.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
      customView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      customView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6)
    ]
    if let utilRow = utilityRow {
      constraints.append(customView.topAnchor.constraint(equalTo: utilRow.bottomAnchor, constant: 7))
    }
    NSLayoutConstraint.activate(constraints)
  }

  private func setupMainContentStack(above botRow: UIView) -> UIStackView {
    if let existing = mainContentStack { return existing }

    let contentStack = ExpandedHitStackView()
    contentStack.axis = .vertical
    contentStack.distribution = .fill
    contentStack.spacing = 5;
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    contentStack.clipsToBounds = false; // 자식들의 확장된 터치 영역 허용
    view.addSubview(contentStack)
    self.mainContentStack = contentStack

    // 높이를 고정하지 않는다. top은 유틸 행 아래(buildKeyboard의 utilRow.bottom 제약),
    // bottom은 바텀 행 위에 핀 고정되므로, 키보드 전체 높이에서 남는 공간을 이 스택이 흡수한다.
    NSLayoutConstraint.activate([
      contentStack.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
      contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6)
    ])

    let numRow = makeNumberRow()
    contentStack.addArrangedSubview(numRow)

    let keyRows: [UIView]
    if isSymbol {
      let rows = isShifted ?
        [KeyboardConstants.SYM_ROW1_SHIFTED, KeyboardConstants.SYM_ROW2_SHIFTED, KeyboardConstants.SYM_ROW3_SHIFTED] :
        [KeyboardConstants.SYM_ROW1_NORMAL, KeyboardConstants.SYM_ROW2_NORMAL, KeyboardConstants.SYM_ROW3_NORMAL]

      let v1 = makeEqualRow(keys: rows[0], rowOffset: 400)
      let v2 = makeLetterRowStack(rows[1], rowOffset: 500) // 9키 대응 로직 사용
      let v3 = makeShiftRow(middleKeys: rows[2], keyValues: rows[2], rowOffset: 600) // 7키 대응 로직 사용
      keyRows = [v1, v2, v3]
    } else {
      keyRows = [makeLetterRow1(), makeLetterRow2(), makeLetterShiftRow()]
    }
    keyRows.forEach { contentStack.addArrangedSubview($0) }

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
    stack.spacing = 5;
    stack.clipsToBounds = false;

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

    // 최상단 유틸 버튼(커서/이모지/키보드 닫기)은 일반 키보다 모서리를 살짝 더 각지게
    let utilRadius = layoutMetrics.utilCornerRadius
    for case let btn as KeyButton in stack.arrangedSubviews {
      btn.layer.cornerRadius = utilRadius
    }

    return stack
  }

  func makeBottomRow() -> UIView {
    let container = ExpandedHitView()
    container.clipsToBounds = false // 가장자리 터치 및 애니메이션 잘림 방지
    let symBtnTitle = isSymbol ? (isHangul ? "한글" : "ENG") : "♥︎"
    let symBtn = makeGlassButton(title: symBtnTitle, id: "symbol", isSpecial: true, tag: 201, fontSize:16)
    symBtn.addTarget(self, action: #selector(symbolTapped), for: .touchUpInside)

    let langBtn = makeGlassButton(title: isHangul ? "ENG" : "한글", id: "lang", isSpecial: true, tag: 202, fontSize:16)
    langBtn.addTarget(self, action: #selector(langTapped), for: .touchUpInside)

    let enterBtn = makeGlassButton(title: "↵", id: "enter", isSpecial: true, tag: 205);
    enterBtn.addTarget(self, action: #selector(enterTapped), for: .touchUpInside);

    let spaceBtn = makeGlassButton(title: "", id: " ", isSpecial: false, tag: 203);
    spaceButton = spaceBtn;
    let dotBtn = makeGlassButton(title: ".", id: ".", isSpecial: false, tag: 204);

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSpacePan(_:)));
    pan.delaysTouchesBegan = false;
    pan.delegate = self;
    spaceBtn.addGestureRecognizer(pan);

    // 꾹 누르면(롱프레스) 드래그 없이도 커서 이동 모드로 진입.
    // 롱프레스가 인식된 뒤에도 pan이 동시 인식되어야 드래그로 커서가 움직인다(delegate).
    let spaceLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleSpaceLongPress(_:)));
    spaceLongPress.minimumPressDuration = 0.3;
    spaceLongPress.delegate = self;
    spaceBtn.addGestureRecognizer(spaceLongPress);

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
    dim.fillColor = UIColor(white: 0.0, alpha: isDarkMode ? 0.45 : 0.22).cgColor
    overlay.layer.addSublayer(dim)

    // 스페이스바 강조 링 (드래그 중인 컨트롤을 또렷이)
    let ring = CAShapeLayer()
    ring.path = UIBezierPath(roundedRect: holeRect, cornerRadius: radius).cgPath
    ring.fillColor = UIColor.clear.cgColor
    ring.strokeColor = (isDarkMode ? UIColor(white: 1.0, alpha: 0.55) : UIColor(white: 0.0, alpha: 0.28)).cgColor
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
    UIView.animate(withDuration: 0.15, animations: {
      overlay.alpha = 0
    }, completion: { _ in
      overlay.removeFromSuperview()
    })
  }

  // MARK: - 버튼 팩토리

  func makeGlassButton(title: String, id: String, isSpecial: Bool, tag: Int = 0, fontSize: CGFloat? = nil) -> KeyButton {
    let btn = KeyButton(type: .custom)
    btn.tag = tag
    btn.keyValue = id
    btn.setTitle(title, for: .normal)
    btn.titleLabel?.font = UIFont.systemFont(ofSize: fontSize ?? layoutMetrics.keyFontSize, weight: isSpecial ? .medium : .regular)
    btn.setTitleColor(isSpecial ? specialTextColor : keyTextColor, for: .normal)
    btn.backgroundColor = isSpecial ? specialGlassColor : keyGlassColor
    btn.normalBackgroundColor = btn.backgroundColor

    btn.layer.cornerRadius = layoutMetrics.cornerRadius;
    // 단색 보더 대신 KeyButton의 림 라이트로 가장자리를 표현 (글래스 느낌)
    btn.layer.shadowColor = UIColor.black.cgColor;
    btn.layer.shadowOffset = CGSize(width: 0, height: 3);
    btn.layer.shadowOpacity = isDarkMode ? 0.30 : 0.12;
    btn.layer.shadowRadius = isDarkMode ? 6 : 3;
    btn.isExclusiveTouch = false;
    btn.touchDelegate = self;
    
    // 버튼 사이의 공백을 터치 영역으로 포함 (가로 3pt, 세로 5pt 간격보다 크게 설정하여 오버랩 생성)
    btn.touchAreaInsets = UIEdgeInsets(top: -3.0, left: -2.0, bottom: -3.0, right: -2.0);

    // 스페이스바는 커서 이동용 롱프레스를 따로 쓰므로 변체 팝업 롱프레스 제외
    if !isSpecial && id != " " {
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
    btn.alpha = 0.2 // 옵시디언 테마에 맞춰 더 투명하게
    btn.layer.cornerRadius = layoutMetrics.cornerRadius / 2
    return btn
  }

  // MARK: - 외관 업데이트
  
  func rebuildKeyboard() {
    CATransaction.begin();
    CATransaction.setDisableActions(true);
    
    if isCustom != wasCustom || isSymbol != wasSymbol {
      updatePanelVisibility();
      wasCustom = isCustom;
      wasSymbol = isSymbol;
    }
    
    // 외관 및 레이블은 패널 전환 여부와 무관하게 항상 업데이트
    updateKeyLabels();
    updateAppearance();
    
    CATransaction.commit();
  }

  func updateAppearance() {
    CATransaction.begin();
    CATransaction.setDisableActions(true);
    
    for btn in allKeyButtons {
      let id = btn.keyValue;
      let isSpecial = (id == "shift" || id == "backspace" || id == "symbol" || id == "lang" || id == "enter" || id == "custom" || id == "dismiss" || id.contains("cursor"));
      
      if id == "shift" {
        let isActive = isShifted || isShiftLocked;
        let targetColor = isActive ? activeGlassColor : specialGlassColor;
        let targetTextC = isActive ? activeTextColor : specialTextColor;
        
        if btn.backgroundColor != targetColor {
          btn.backgroundColor = targetColor;
          btn.normalBackgroundColor = btn.backgroundColor;
        }
        
        if btn.titleColor(for: .normal) != targetTextC {
          btn.setTitleColor(targetTextC, for: .normal);
          btn.tintColor = targetTextC;
        }
        
        let targetTitle = isSymbol ? (isShifted ? "2/2" : "1/2") : (isShiftLocked ? "⇪" : "⇧");
        if btn.title(for: .normal) != targetTitle {
          btn.setTitle(targetTitle, for: .normal);
          btn.titleLabel?.font = UIFont.systemFont(ofSize: isSymbol ? 16 : layoutMetrics.keyFontSize, weight: .medium);
        }
      }
      
      if id != "shift" {
        let targetColor = isSpecial ? specialGlassColor : keyGlassColor;
        if btn.backgroundColor != targetColor {
          btn.backgroundColor = targetColor;
          btn.normalBackgroundColor = btn.backgroundColor;
        }
        
        let targetTextColor = isSpecial ? specialTextColor : keyTextColor;
        if btn.titleColor(for: .normal) != targetTextColor {
          btn.setTitleColor(targetTextColor, for: .normal);
          btn.tintColor = targetTextColor;
        }
      }
      
      btn.layer.shadowOpacity = Float(isDarkMode ? 0.30 : 0.12);
      btn.layer.shadowRadius = isDarkMode ? 6 : 3;

      // 글래스 레이어(바디 광택 + 림 라이트) 업데이트 (중앙 집중식 관리)
      btn.updateLayerAppearance();
    }
    
    CATransaction.commit();
  }

  // MARK: - 개별 행 생성
  
  func makeNumberRow() -> UIView {
    let row = makeEqualRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"], rowOffset: 300);
    if let stack = row as? UIStackView {
      let buttons = stack.arrangedSubviews.compactMap { $0 as? KeyButton };
      for (idx, btn) in buttons.enumerated() {
        // 숫자 행은 상단 여백을 위해 top을 더 크게 확장
        btn.touchAreaInsets.top = -10.0;
        if idx == 0 { btn.touchAreaInsets.left = -10.0; }
        if idx == buttons.count - 1 { btn.touchAreaInsets.right = -10.0; }
      }
    }
    return row;
  }

  func makeLetterRow1() -> UIView {
    let row = makeLetterRowStack(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"], rowOffset: 400);
    if let stack = row.subviews.first as? UIStackView {
      let buttons = stack.arrangedSubviews.compactMap { $0 as? KeyButton };
      for (idx, btn) in buttons.enumerated() {
        if idx == 0 { btn.touchAreaInsets.left = -10.0; }
        if idx == buttons.count - 1 { btn.touchAreaInsets.right = -10.0; }
      }
    }
    return row;
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
    container.clipsToBounds = false;
    let stack = ExpandedHitStackView()
    stack.axis = .horizontal
    stack.distribution = .fill
    stack.spacing = 3;
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.clipsToBounds = false;
    
    // 9개 버튼일 경우 양옆에 더미 버튼 추가
    if chars.count == 9 {
      let leftDummy = makeDummyButton()
      let rightDummy = makeDummyButton()
      
      stack.addArrangedSubview(leftDummy)
      
      var firstKey: UIView?
      for (idx, ch) in chars.enumerated() {
        let label = isSymbol ? ch : (ch.count == 1 ? letterLabel(for: Character(ch)) : ch);
        let key = makeGlassButton(title: label, id: ch, isSpecial: false, tag: rowOffset + idx);
        stack.addArrangedSubview(key);
        
        if let first = firstKey {
          key.widthAnchor.constraint(equalTo: first.widthAnchor).isActive = true;
        } else {
          firstKey = key;
        }
      }
      
      stack.addArrangedSubview(rightDummy);
      
      let keyButtons = stack.arrangedSubviews.compactMap { $0 as? KeyButton };
      if let firstKeyBtn = keyButtons.first(where: { $0.keyValue != "dummy" }) {
        // 첫 번째 키(예: 'a')의 왼쪽 터미 영역까지 확장
        firstKeyBtn.touchAreaInsets.left = -40;
      }
      if let lastKeyBtn = keyButtons.last(where: { $0.keyValue != "dummy" }) {
        // 마지막 키(예: 'l')의 오른쪽 터미 영역까지 확장
        lastKeyBtn.touchAreaInsets.right = -40;
      }

      if let key = firstKey {
        // 양옆 공백(더미)을 키 폭의 0.4배로 — 0.3 대비 살짝 넓혀 9키 행 버튼을 조금 좁힌다
        leftDummy.widthAnchor.constraint(equalTo: key.widthAnchor, multiplier: 0.4).isActive = true;
        rightDummy.widthAnchor.constraint(equalTo: key.widthAnchor, multiplier: 0.4).isActive = true;
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
    let stack = ExpandedHitStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 3;
    stack.clipsToBounds = false;
    for (idx, key) in keys.enumerated() {
      stack.addArrangedSubview(makeGlassButton(title: key, id: key, isSpecial: false, tag: rowOffset + idx))
    }
    return stack
  }

  func makeShiftRow(middleKeys: [String], keyValues: [String], rowOffset: Int) -> UIView {
    let container = ExpandedHitView()
    container.clipsToBounds = false // 가장자리 애니메이션 잘림 방지
    
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
    
    let shiftBtn = makeGlassButton(title: shiftTitle, id: "shift", isSpecial: true, tag: 699, fontSize: fontSize)
    shiftBtn.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
    
    // 시프트 롱 프레스 추가 (0.5초)
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleShiftLongPress(_:)))
    longPress.minimumPressDuration = 0.5
    shiftBtn.addGestureRecognizer(longPress)
    
    shiftButton = shiftBtn;

    let bsBtn = makeGlassButton(title: "⌫", id: "backspace", isSpecial: true, tag: 698)
    bsBtn.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
    bsBtn.addTarget(self, action: #selector(backspaceTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

    let letterStack = UIStackView();
    letterStack.axis = .horizontal; letterStack.distribution = .fillEqually; letterStack.spacing = 3;
    for (idx, (label, value)) in zip(middleKeys, keyValues).enumerated() {
      letterStack.addArrangedSubview(makeGlassButton(title: label, id: value, isSpecial: false, tag: rowOffset + idx))
    }

    [shiftBtn, letterStack, bsBtn].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; container.addSubview($0) }
    
    // 시프트 행의 하단 여백 및 좌우 여백 확장
    shiftBtn.touchAreaInsets.bottom = -10.0;
    shiftBtn.touchAreaInsets.left = -8.0;
    bsBtn.touchAreaInsets.bottom = -10.0;
    bsBtn.touchAreaInsets.right = -8.0;
    for btn in letterStack.arrangedSubviews.compactMap({ $0 as? KeyButton }) {
      btn.touchAreaInsets.bottom = -10.0;
    }
    
    let letterKeys = letterStack.arrangedSubviews.compactMap { $0 as? KeyButton }
    NSLayoutConstraint.activate([
      shiftBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor), shiftBtn.topAnchor.constraint(equalTo: container.topAnchor),
      shiftBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      letterStack.leadingAnchor.constraint(equalTo: shiftBtn.trailingAnchor, constant: 3), letterStack.trailingAnchor.constraint(equalTo: bsBtn.leadingAnchor, constant: -3),
      letterStack.topAnchor.constraint(equalTo: container.topAnchor), letterStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      bsBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor), bsBtn.topAnchor.constraint(equalTo: container.topAnchor),
      bsBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])
    // ⇧/⌫ 폭을 글자 키의 1.5배로 고정 → 표준 10열 그리드에 맞아 글자 키 폭이 다른 행과 거의 동일해진다.
    if let letterKey = letterKeys.first {
      NSLayoutConstraint.activate([
        shiftBtn.widthAnchor.constraint(equalTo: letterKey.widthAnchor, multiplier: 1.5),
        bsBtn.widthAnchor.constraint(equalTo: letterKey.widthAnchor, multiplier: 1.5)
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
          let keys = isShifted ? KeyboardConstants.SYM_ROW1_SHIFTED : KeyboardConstants.SYM_ROW1_NORMAL;
          let target = keys[idx];
          if btn.title(for: .normal) != target { btn.setTitle(target, for: .normal); btn.keyValue = target; }
        } else {
          let ch = row1Normal[idx];
          let target = letterLabel(for: ch);
          if btn.title(for: .normal) != target { btn.setTitle(target, for: .normal); btn.keyValue = String(ch); }
        }
      case 500...509:
        let idx = btn.tag - 500;
        if isSymbol {
          let keys = isShifted ? KeyboardConstants.SYM_ROW2_SHIFTED : KeyboardConstants.SYM_ROW2_NORMAL;
          let target = keys[idx];
          if btn.title(for: .normal) != target { btn.setTitle(target, for: .normal); btn.keyValue = target; }
        } else {
          let ch = row2Normal[idx];
          let target = letterLabel(for: ch);
          if btn.title(for: .normal) != target { btn.setTitle(target, for: .normal); btn.keyValue = String(ch); }
        }
      case 600...606:
        let idx = btn.tag - 600;
        if isSymbol {
          let keys = isShifted ? KeyboardConstants.SYM_ROW3_SHIFTED : KeyboardConstants.SYM_ROW3_NORMAL;
          let target = keys[idx];
          if btn.title(for: .normal) != target { btn.setTitle(target, for: .normal); btn.keyValue = target; }
        } else {
          let ch = row3Normal[idx];
          let target = letterLabel(for: ch);
          if btn.title(for: .normal) != target { btn.setTitle(target, for: .normal); btn.keyValue = String(ch); }
        }
      case 699:
        let targetTitle = isShiftLocked ? "⇪" : "⇧";
        if btn.title(for: .normal) != targetTitle {
          btn.setTitle(targetTitle, for: .normal);
        }
      default: break
      }
    }
  }
}

