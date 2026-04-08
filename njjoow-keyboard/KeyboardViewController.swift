//
//  KeyboardViewController.swift
//  njjoow-keyboard
//
//  Created by 이우진 on 4/8/26.
//

import UIKit

// MARK: - 한글 배열

private let HANGUL_MAP: [Character: Character] = [
  "q": "ㅂ", "w": "ㅈ", "e": "ㄷ", "r": "ㄱ", "t": "ㅅ",
  "y": "ㅛ", "u": "ㅕ", "i": "ㅑ", "o": "ㅐ", "p": "ㅔ",
  "a": "ㅁ", "s": "ㄴ", "d": "ㅇ", "f": "ㄹ", "g": "ㅎ",
  "h": "ㅗ", "j": "ㅓ", "k": "ㅏ", "l": "ㅣ",
  "z": "ㅋ", "x": "ㅌ", "c": "ㅊ", "v": "ㅍ", "b": "ㅠ",
  "n": "ㅜ", "m": "ㅡ"
]

private let HANGUL_SHIFT_MAP: [Character: Character] = [
  "q": "ㅃ", "w": "ㅉ", "e": "ㄸ", "r": "ㄲ", "t": "ㅆ",
  "o": "ㅒ", "p": "ㅖ"
]

// MARK: - 기호 배열

private let SYM_ROW1_NORMAL: [String]  = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
private let SYM_ROW2_NORMAL: [String]  = ["-", "/", ":", ";", "(", ")", "₩", "&", "@", "\""]
private let SYM_ROW3_NORMAL: [String]  = [".", ",", "♥", "★", "?", "!", "'"]

private let SYM_ROW1_SHIFTED: [String] = ["○", "●", "□", "■", "←", "↑", "↓", "→", "↔", "÷"]
private let SYM_ROW2_SHIFTED: [String] = ["_", "\\", "|", "~", "<", ">", "$", "￡", "￥", "•"]
private let SYM_ROW3_SHIFTED: [String] = [".", ",", "♡", "☆", "?", "!", "'"]

// MARK: - 이모지 배열

private let COMMON_EMOJIS: [String] = [
  "😀", "😂", "🥹", "😍", "🥰", "😊", "😎", "🤔",
  "😅", "😭", "😱", "🤯", "🥺", "😏", "😒", "😡",
  "👍", "👎", "👏", "🙏", "🤝", "✌️", "💪", "🤞",
  "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "💔",
  "🔥", "⭐", "🌟", "✨", "💥", "🎉", "🎊", "🌈",
  "🍎", "🍕", "🍔", "🍜", "🍣", "☕", "🍰", "🍫",
  "🐶", "🐱", "🐰", "🐻", "🐼", "🐨", "🦊", "🐯",
  "⚽", "🏀", "🎮", "🎲", "🚀", "✈️", "🚗", "💻",
  "😆", "🤣", "🙂", "🙃", "😉", "😇", "🥳", "🤩",
  "👋", "🤚", "🖐", "✋", "🤙", "👌", "🤌", "☝",
  "💕", "💞", "💓", "💗", "💖", "💘", "💝", "❣️",
  "🌸", "🌺", "🌹", "🌻", "🌼", "🍀", "🌿", "🌊"
]

// MARK: - KeyButton

private class KeyButton: UIButton {
  var keyValue: String = ""
}

// MARK: - KeyboardViewController

class KeyboardViewController: UIInputViewController {

  // MARK: 상태

  private var isHangul: Bool = false
  private var isShifted: Bool = false
  private var isSymbol: Bool = false
  private var isEmoji: Bool = false
  private var automata = HangulAutomata()
  private var composingChar: Character? = nil
  private var allKeyButtons: [KeyButton] = []
  private var shiftButton: KeyButton?

  // MARK: 팝업 상태 (Long Press)
  private var popupView: UIView?
  private var popupLabels: [UILabel] = []
  private var popupItems: [String] = []
  private var popupSelectedIndex: Int = -1

  // MARK: - Backspace 빠른 지우기 및 햅틱
  private var backspaceStartTimer: Timer?
  private var backspaceTimer: Timer?
  private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

  // MARK: 레이아웃 상수

  private let UTIL_ROW_H: CGFloat = 34   
  private let KEY_FONT_SIZE: CGFloat = 20 
  private let MAIN_KEY_H: CGFloat = 36
  private let BOTTOM_ROW_H: CGFloat = 38
  private let CORNER_RADIUS: CGFloat = 8

  // MARK: 글래스모피즘 색상 (라이트/다크 대응)

  private var isDarkMode: Bool {
    if textDocumentProxy.keyboardAppearance == .dark {
      return true
    } else if textDocumentProxy.keyboardAppearance == .light {
      return false
    }
    return traitCollection.userInterfaceStyle == .dark
  }

  /// 일반 키 배경 (유리 효과)
  private var keyGlassColor: UIColor {
    return isDarkMode
      ? UIColor(white: 1.0, alpha: 0.14)
      : UIColor(white: 1.0, alpha: 0.28)
  }

  /// 특수 키 배경 (더 어두운 유리)
  private var specialGlassColor: UIColor {
    return isDarkMode
      ? UIColor(white: 1.0, alpha: 0.06)
      : UIColor(white: 0.2, alpha: 0.06)
  }

  /// 활성화된 시프트 배경
  private var activeGlassColor: UIColor {
    return isDarkMode
      ? UIColor(white: 1.0, alpha: 0.5)
      : UIColor(white: 0.5, alpha: 0.3)
  }

  /// 키 테두리 색상
  private var keyBorderColor: CGColor {
    return isDarkMode
      ? UIColor(white: 1.0, alpha: 0.12).cgColor
      : UIColor(white: 0.0, alpha: 0.08).cgColor
  }

  private var keyTextColor: UIColor {
    return isDarkMode ? .white : .black
  }

  private var specialTextColor: UIColor {
    return isDarkMode ? UIColor(white: 0.85, alpha: 1) : .darkGray
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    buildKeyboard()
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      rebuildKeyboard()
    }
  }



  // MARK: - 전체 레이아웃 빌드

  private func buildKeyboard() {
    view.subviews.forEach { $0.removeFromSuperview() }
    allKeyButtons.removeAll()
    shiftButton = nil
    // 유틸리티 행 (최상단 고정)
    let utilRow = makeUtilityRow()
    utilRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(utilRow)

    // 하단 기능 행 (최하단 고정)
    let botRow = makeBottomRow()
    botRow.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(botRow)

    NSLayoutConstraint.activate([
      utilRow.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
      utilRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      utilRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      utilRow.heightAnchor.constraint(equalToConstant: UTIL_ROW_H),

      botRow.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
      botRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
      botRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
      botRow.heightAnchor.constraint(equalToConstant: BOTTOM_ROW_H)
    ])

    if isEmoji {
      let emojiView = makeEmojiPanel()
      emojiView.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(emojiView)
      NSLayoutConstraint.activate([
        emojiView.topAnchor.constraint(equalTo: utilRow.bottomAnchor, constant: 7),
        emojiView.bottomAnchor.constraint(equalTo: botRow.topAnchor, constant: -7),
        emojiView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
        emojiView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6)
      ])
    } else {
      // 콘텐츠 스택 (숫자 행 + 문자/기호 행)
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

      // 숫자 행 (항상) - 남은 공간을 차지하도록 Distribution .fill 상태에서 별도 높이 지정 안 함
      contentStack.addArrangedSubview(makeNumberRow())

      if isSymbol {
        let row1 = isShifted ? SYM_ROW1_SHIFTED : SYM_ROW1_NORMAL
        let row2 = isShifted ? SYM_ROW2_SHIFTED : SYM_ROW2_NORMAL
        let row3 = isShifted ? SYM_ROW3_SHIFTED : SYM_ROW3_NORMAL
        
        let v1 = makeEqualRow(keys: row1)
        let v2 = makeEqualRow(keys: row2)
        let v3 = makeShiftRow(middleKeys: row3, keyValues: row3)
        
        [v1, v2, v3].forEach {
          $0.heightAnchor.constraint(equalToConstant: MAIN_KEY_H).isActive = true
          contentStack.addArrangedSubview($0)
        }
      } else {
        let v1 = makeLetterRow1()
        let v2 = makeLetterRow2()
        let v3 = makeLetterShiftRow()
        
        [v1, v2, v3].forEach {
          $0.heightAnchor.constraint(equalToConstant: MAIN_KEY_H).isActive = true
          contentStack.addArrangedSubview($0)
        }
      }
    }
  }

  // MARK: - 유틸리티 행

  private func makeUtilityRow() -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 5

    // 커서 버튼 4방향
    let cursors: [(String, String)] = [
      ("◀", "cursor_left"),
      ("▲", "cursor_up"),
      ("▼", "cursor_down"),
      ("▶", "cursor_right")
    ]
    for (title, id) in cursors {
      let btn = makeGlassButton(title: title, id: id, isSpecial: true)
      btn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
      btn.addTarget(self, action: #selector(cursorTapped(_:)), for: .touchUpInside)
      stack.addArrangedSubview(btn)
    }

    // 이모지 토글
    let emojiBtn = makeGlassButton(title: "☻", id: "emoji", isSpecial: true)
    emojiBtn.titleLabel?.font = UIFont.systemFont(ofSize: 22)
    if isEmoji { emojiBtn.backgroundColor = activeGlassColor }
    emojiBtn.addTarget(self, action: #selector(emojiTapped), for: .touchUpInside)
    stack.addArrangedSubview(emojiBtn)

    // 키보드 닫기 (SF Symbol: keyboard.chevron.compact.down)
    let dismissBtn = makeGlassButton(title: "", id: "dismiss", isSpecial: true)
    if let img = UIImage(systemName: "keyboard.chevron.compact.down") {
      dismissBtn.setImage(img.withRenderingMode(.alwaysTemplate), for: .normal)
      dismissBtn.tintColor = specialTextColor
    } else {
      dismissBtn.setTitle("▼", for: .normal)
    }
    dismissBtn.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    stack.addArrangedSubview(dismissBtn)

    return stack
  }

  // MARK: - 행 생성

  private func makeNumberRow() -> UIView {
    makeEqualRow(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
  }

  private func makeLetterRow1() -> UIView {
    makeLetterRowStack(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
  }

  private func makeLetterRow2() -> UIView {
    makeLetterRowStack(["a", "s", "d", "f", "g", "h", "j", "k", "l"])
  }

  private func makeLetterShiftRow() -> UIView {
    let chars: [Character] = ["z", "x", "c", "v", "b", "n", "m"]
    let labels = chars.map { letterLabel(for: $0) }
    let keys   = chars.map { String($0) }
    return makeShiftRow(middleKeys: labels, keyValues: keys)
  }

  // MARK: - 공통 행 빌더

  private func makeLetterRowStack(_ chars: [Character]) -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 5
    for ch in chars {
      stack.addArrangedSubview(
        makeGlassButton(title: letterLabel(for: ch), id: String(ch), isSpecial: false)
      )
    }
    return stack
  }

  private func makeEqualRow(keys: [String]) -> UIView {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.distribution = .fillEqually
    stack.spacing = 5
    for key in keys {
      stack.addArrangedSubview(makeGlassButton(title: key, id: key, isSpecial: false))
    }
    return stack
  }

  /// ⇧ + 중간 키들 + ⌫ 행
  private func makeShiftRow(middleKeys: [String], keyValues: [String]) -> UIView {
    let container = UIView()

    let shiftTitle = isShifted ? "⇪" : "⇧"
    let shiftBtn = makeGlassButton(title: shiftTitle, id: "shift", isSpecial: true)
    shiftBtn.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
    if isShifted { shiftBtn.backgroundColor = activeGlassColor }
    shiftButton = shiftBtn

    let bsBtn = makeGlassButton(title: "⌫", id: "backspace", isSpecial: true)
    bsBtn.addTarget(self, action: #selector(backspaceTouchDown(_:)), for: .touchDown)
    bsBtn.addTarget(self, action: #selector(backspaceTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

    let letterStack = UIStackView()
    letterStack.axis = .horizontal
    letterStack.distribution = .fillEqually
    letterStack.spacing = 5

    for (label, value) in zip(middleKeys, keyValues) {
      let btn = makeGlassButton(title: label, id: value, isSpecial: false)
      letterStack.addArrangedSubview(btn)
    }

    [shiftBtn, letterStack, bsBtn].forEach {
      $0.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview($0)
    }

    NSLayoutConstraint.activate([
      shiftBtn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      shiftBtn.topAnchor.constraint(equalTo: container.topAnchor),
      shiftBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      shiftBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.13),

      letterStack.leadingAnchor.constraint(equalTo: shiftBtn.trailingAnchor, constant: 5),
      letterStack.trailingAnchor.constraint(equalTo: bsBtn.leadingAnchor, constant: -5),
      letterStack.topAnchor.constraint(equalTo: container.topAnchor),
      letterStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

      bsBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      bsBtn.topAnchor.constraint(equalTo: container.topAnchor),
      bsBtn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
      bsBtn.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.13)
    ])

    return container
  }

  // MARK: - 하단 기능 행

  private func makeBottomRow() -> UIView {
    let container = UIView()

    let symBtnTitle = isSymbol ? (isHangul ? "한글" : "ENG") : "♥︎"
    let symBtn   = makeGlassButton(title: symBtnTitle, id: "symbol", isSpecial: true)
    symBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
    symBtn.addTarget(self, action: #selector(symbolTapped), for: .touchUpInside)

    let langBtn  = makeGlassButton(title: isHangul ? "ENG" : "한글", id: "lang", isSpecial: true)
    langBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
    langBtn.addTarget(self, action: #selector(langTapped), for: .touchUpInside)

    let spaceBtn = makeGlassButton(title: "", id: " ", isSpecial: false)

    let dotBtn   = makeGlassButton(title: ".", id: ".", isSpecial: false)

    let enterBtn = makeGlassButton(title: "↵", id: "enter", isSpecial: true)
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

  // MARK: - 이모지 패널

  private func makeEmojiPanel() -> UIView {
    let scrollView = UIScrollView()
    scrollView.showsVerticalScrollIndicator = true
    scrollView.backgroundColor = .clear

    let containerStack = UIStackView()
    containerStack.axis = .vertical
    containerStack.spacing = 7
    containerStack.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(containerStack)

    let cols = 8
    var idx = 0
    while idx < COMMON_EMOJIS.count {
      let rowStack = UIStackView()
      rowStack.axis = .horizontal
      rowStack.distribution = .fillEqually
      rowStack.spacing = 5

      for i in idx..<min(idx + cols, COMMON_EMOJIS.count) {
        let emoji = COMMON_EMOJIS[i]
        let btn = UIButton(type: .system)
        btn.setTitle(emoji, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 26)
        btn.backgroundColor = keyGlassColor
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = keyBorderColor
        btn.accessibilityLabel = emoji
        btn.addTarget(self, action: #selector(emojiKeyTapped(_:)), for: .touchUpInside)
        rowStack.addArrangedSubview(btn)
      }
      containerStack.addArrangedSubview(rowStack)
      idx += cols
    }

    NSLayoutConstraint.activate([
      containerStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      containerStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      containerStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      containerStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      containerStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
    ])

    return scrollView
  }

  // MARK: - 글래스 버튼 팩토리

  private func makeGlassButton(title: String, id: String, isSpecial: Bool) -> KeyButton {
    let btn = KeyButton(type: .system)
    btn.keyValue = id
    btn.setTitle(title, for: .normal)

    let fontSize = KEY_FONT_SIZE
    btn.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: isSpecial ? .medium : .regular)
    btn.setTitleColor(isSpecial ? specialTextColor : keyTextColor, for: .normal)

    // 글래스 배경
    btn.backgroundColor = isSpecial ? specialGlassColor : keyGlassColor

    // 테두리 (글래스 효과 핵심)
    btn.layer.cornerRadius = CORNER_RADIUS
    btn.layer.borderWidth = 0.5
    btn.layer.borderColor = keyBorderColor
    btn.layer.masksToBounds = false

    // 소프트 그림자
    btn.layer.shadowColor = UIColor.black.cgColor
    btn.layer.shadowOffset = CGSize(width: 0, height: 1)
    btn.layer.shadowOpacity = isDarkMode ? 0.5 : 0.15
    btn.layer.shadowRadius = isDarkMode ? 4 : 2

    // 액션
    if !isSpecial {
      btn.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
      let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
      lp.minimumPressDuration = 0.4
      btn.addGestureRecognizer(lp)
    }

    allKeyButtons.append(btn)
    return btn
  }

  // MARK: - 문자 레이블 결정

  private func letterLabel(for char: Character) -> String {
    if isHangul {
      if isShifted, let s = HANGUL_SHIFT_MAP[char] { return String(s) }
      return String(HANGUL_MAP[char] ?? char)
    } else {
      return isShifted ? String(char).uppercased() : String(char)
    }
  }

  // MARK: - 액션

  @objc private func letterTapped(_ sender: KeyButton) {
    let key = sender.keyValue
    guard let ch = key.first else { return }

    if isHangul && ch.isLetter && !isSymbol {
      inputHangul(ch)
    } else {
      let toInsert = (ch.isLetter && isShifted && !isSymbol) ? key.uppercased() : key
      textDocumentProxy.insertText(toInsert)
    }

    if isShifted {
      isShifted = false
      rebuildKeyboard()
    }
  }

  @objc private func shiftTapped() {
    isShifted.toggle()
    rebuildKeyboard()
  }

  @objc private func backspaceTouchDown(_ sender: UIButton) {
    handleBackspace()
    hapticGenerator.impactOccurred()
    
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
    backspaceStartTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
      self?.startContinuousBackspace()
    }
  }

  private func startContinuousBackspace() {
    backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.handleBackspace()
      self?.hapticGenerator.impactOccurred()
    }
  }

  @objc private func backspaceTouchUp(_ sender: UIButton) {
    backspaceStartTimer?.invalidate()
    backspaceTimer?.invalidate()
  }

  private func handleBackspace() {
    if isHangul && !isSymbol {
      let result = automata.backspace()
      if composingChar != nil {
        textDocumentProxy.deleteBackward()
        composingChar = nil
      } else {
        for _ in 0..<result.deleteCount { textDocumentProxy.deleteBackward() }
      }
      if !result.insert.isEmpty {
        textDocumentProxy.insertText(result.insert)
        composingChar = result.insert.last
      }
    } else {
      textDocumentProxy.deleteBackward()
    }
  }

  @objc private func langTapped() {
    flushHangul()
    isHangul.toggle()
    automata.reset()
    composingChar = nil
    isEmoji = false
    isSymbol = false   // 기호 모드에서 눌러도 문자 모드로 전환
    rebuildKeyboard()
  }

  @objc private func symbolTapped() {
    flushHangul()
    isSymbol.toggle()
    isShifted = false
    isEmoji = false
    rebuildKeyboard()
  }

  @objc private func enterTapped() {
    flushHangul()
    textDocumentProxy.insertText("\n")
  }

  // MARK: - 롱프레스 팝업 (Long Press)

  private func getVariants(for char: String) -> [String] {
    if isHangul {
      switch char {
      case "ㅂ": return ["ㅂ", "ㅃ"]
      case "ㅈ": return ["ㅈ", "ㅉ"]
      case "ㄷ": return ["ㄷ", "ㄸ"]
      case "ㄱ": return ["ㄱ", "ㄲ"]
      case "ㅅ": return ["ㅅ", "ㅆ"]
      case "ㅐ": return ["ㅐ", "ㅒ"]
      case "ㅔ": return ["ㅔ", "ㅖ"]
        
      case "ㅃ": return ["ㅃ", "ㅂ"]
      case "ㅉ": return ["ㅉ", "ㅈ"]
      case "ㄸ": return ["ㄸ", "ㄷ"]
      case "ㄲ": return ["ㄲ", "ㄱ"]
      case "ㅆ": return ["ㅆ", "ㅅ"]
      case "ㅒ": return ["ㅒ", "ㅐ"]
      case "ㅖ": return ["ㅖ", "ㅔ"]

      default: return [char]
      }
    } else if !isSymbol && !isEmoji {
      // 영문
      let isUpper = char == char.uppercased()
      let lower = char.lowercased()
      let upper = char.uppercased()
      
      // 알파벳인지 확인
      if lower != upper {
        if isUpper {
          return [upper, lower]
        } else {
          return [lower, upper]
        }
      }
      return [char]
    }
    return [char]
  }

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard let btn = gesture.view as? KeyButton else { return }
    let char = letterLabel(for: btn.keyValue.first!) // Shift가 켜진 상태라면 대문자/쌍자음 기반으로 파생
    
    switch gesture.state {
    case .began:
      let variants = getVariants(for: char)
      if variants.count <= 1 {
          gesture.state = .failed
          return
      }
      showPopup(for: btn, variants: variants)
      updatePopupSelection(touchLocationInView: gesture.location(in: self.view))
    case .changed:
      updatePopupSelection(touchLocationInView: gesture.location(in: self.view))
    case .ended:
      if popupSelectedIndex >= 0 && popupSelectedIndex < popupItems.count {
          let selected = popupItems[popupSelectedIndex]
          insertVariant(selected)
      }
      hidePopup()
    case .cancelled, .failed:
      hidePopup()
    default:
      break
    }
  }

  private func showPopup(for btn: KeyButton, variants: [String]) {
    hidePopup()
    
    popupItems = variants
    popupSelectedIndex = -1
    
    let popup = UIView()
    popup.layer.cornerRadius = 10
    popup.layer.shadowColor = UIColor.black.cgColor
    popup.layer.shadowOpacity = isDarkMode ? 0.5 : 0.2
    popup.layer.shadowRadius = 4
    popup.layer.shadowOffset = CGSize(width: 0, height: 2)

    let blurStyle: UIBlurEffect.Style = isDarkMode ? .systemMaterialDark : .systemMaterialLight
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    blur.layer.cornerRadius = 10
    blur.layer.masksToBounds = true
    popup.addSubview(blur)
    
    let btnFrame = btn.convert(btn.bounds, to: self.view)
    let itemWidth: CGFloat = max(btnFrame.width * 1.2, 40)
    let itemHeight: CGFloat = btnFrame.height * 1.2
    
    popup.frame = CGRect(
        x: btnFrame.midX - (CGFloat(variants.count) * itemWidth) / 2,
        y: btnFrame.minY - itemHeight - 8,
        width: CGFloat(variants.count) * itemWidth,
        height: itemHeight
    )
    
    if popup.frame.minX < 5 {
        popup.frame.origin.x = 5
    } else if popup.frame.maxX > self.view.bounds.width - 5 {
        popup.frame.origin.x = self.view.bounds.width - 5 - popup.frame.width
    }
    
    blur.frame = popup.bounds
    
    for (i, v) in variants.enumerated() {
        let lbl = UILabel(frame: CGRect(x: CGFloat(i) * itemWidth, y: 0, width: itemWidth, height: itemHeight))
        lbl.text = v
        lbl.font = UIFont.systemFont(ofSize: KEY_FONT_SIZE + 4, weight: .medium)
        lbl.textAlignment = .center
        lbl.textColor = keyTextColor
        lbl.layer.cornerRadius = 6
        lbl.layer.masksToBounds = true
        popup.addSubview(lbl)
        popupLabels.append(lbl)
    }
    
    self.view.addSubview(popup)
    self.popupView = popup
  }

  private func updatePopupSelection(touchLocationInView: CGPoint) {
    guard let popup = popupView, !popupItems.isEmpty else { return }
    
    let localX = touchLocationInView.x - popup.frame.minX
    let itemWidth = popup.bounds.width / CGFloat(popupItems.count)
    var newIdx = Int(localX / itemWidth)
    
    if newIdx < 0 { newIdx = 0 }
    if newIdx >= popupItems.count { newIdx = popupItems.count - 1 }
    
    popupSelectedIndex = newIdx
    
    for (i, lbl) in popupLabels.enumerated() {
        if i == popupSelectedIndex {
            lbl.backgroundColor = activeGlassColor
            lbl.textColor = isDarkMode ? .white : .black
        } else {
            lbl.backgroundColor = .clear
            lbl.textColor = keyTextColor
        }
    }
  }

  private func hidePopup() {
    popupView?.removeFromSuperview()
    popupView = nil
    popupLabels.removeAll()
    popupItems.removeAll()
    popupSelectedIndex = -1
  }

  private func insertVariant(_ selected: String) {
    if isHangul {
      let result = automata.insert(char: Character(selected))
      if composingChar != nil {
        textDocumentProxy.deleteBackward()
      }
      for _ in 0..<result.deleteCount {
        textDocumentProxy.deleteBackward()
      }
      if !result.insert.isEmpty {
        textDocumentProxy.insertText(result.insert)
        composingChar = result.insert.last
      } else {
        composingChar = nil
      }
    } else {
      textDocumentProxy.insertText(selected)
    }
    
    // shift 1회용 해제
    if isShifted {
        isShifted = false
        rebuildKeyboard()
    }
  }

  // MARK: - 커서 이동 (정확한 줄 이동)

  @objc private func cursorTapped(_ sender: KeyButton) {
    switch sender.keyValue {
    case "cursor_left":
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -1)

    case "cursor_right":
      textDocumentProxy.adjustTextPosition(byCharacterOffset: 1)

    case "cursor_up":
      moveCursorUp()

    case "cursor_down":
      moveCursorDown()

    default:
      break
    }
  }

  /// 커서를 위 줄의 같은 열 위치로 이동
  private func moveCursorUp() {
    let before = textDocumentProxy.documentContextBeforeInput ?? ""

    // 현재 줄에서 커서까지의 열 위치 계산
    let currentCol: Int
    if let lastNlRange = before.range(of: "\n", options: .backwards) {
      currentCol = before.distance(from: lastNlRange.upperBound, to: before.endIndex)
    } else {
      // 첫 번째 줄 → 맨 앞으로
      textDocumentProxy.adjustTextPosition(byCharacterOffset: -before.count)
      return
    }

    // 이전 줄 내용 추출 (마지막 \n 이전 텍스트)
    let beforeLastNl = String(before[before.startIndex..<before.range(of: "\n", options: .backwards)!.lowerBound])

    let prevLineStart: String.Index
    if let prevNlRange = beforeLastNl.range(of: "\n", options: .backwards) {
      prevLineStart = prevNlRange.upperBound
    } else {
      prevLineStart = beforeLastNl.startIndex
    }
    let prevLineLen = beforeLastNl.distance(from: prevLineStart, to: beforeLastNl.endIndex)
    let targetCol = min(currentCol, prevLineLen)

    // 이동량: 현재열 + \n(1) + (이전줄 길이 - 목표열)
    let offset = -(currentCol + 1 + (prevLineLen - targetCol))
    textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
  }

  /// 커서를 아래 줄의 같은 열 위치로 이동
  private func moveCursorDown() {
    let before = textDocumentProxy.documentContextBeforeInput ?? ""
    let after  = textDocumentProxy.documentContextAfterInput ?? ""

    // 현재 줄에서 커서까지의 열 위치
    let currentCol: Int
    if let lastNlRange = before.range(of: "\n", options: .backwards) {
      currentCol = before.distance(from: lastNlRange.upperBound, to: before.endIndex)
    } else {
      currentCol = before.count
    }

    // after에서 현재 줄 나머지 + 다음 줄 찾기
    guard let firstNlIdx = after.firstIndex(of: "\n") else {
      // 다음 줄 없음 → 맨 끝으로
      textDocumentProxy.adjustTextPosition(byCharacterOffset: after.count)
      return
    }

    // 현재 줄 나머지 길이 (커서 ~ 줄 끝)
    let restOfCurrentLine = after.distance(from: after.startIndex, to: firstNlIdx)

    // 다음 줄 내용 추출
    let nextLineStart = after.index(after: firstNlIdx)
    let nextLineContent: String
    if nextLineStart < after.endIndex {
      let remaining = String(after[nextLineStart...])
      if let nextNlIdx = remaining.firstIndex(of: "\n") {
        nextLineContent = String(remaining[remaining.startIndex..<nextNlIdx])
      } else {
        nextLineContent = remaining
      }
    } else {
      nextLineContent = ""
    }

    let nextLineLen = nextLineContent.count
    let targetCol = min(currentCol, nextLineLen)

    // 이동량: 현재 줄 나머지 + \n(1) + 목표열
    let offset = restOfCurrentLine + 1 + targetCol
    textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
  }

  // MARK: - 이모지 / 닫기

  @objc private func emojiTapped() {
    flushHangul()
    isEmoji.toggle()
    isSymbol = false
    rebuildKeyboard()
  }

  @objc private func dismissTapped() {
    self.dismissKeyboard()
  }

  @objc private func emojiKeyTapped(_ sender: UIButton) {
    if let emoji = sender.accessibilityLabel {
      textDocumentProxy.insertText(emoji)
    }
  }

  // MARK: - 한글 입력

  private func inputHangul(_ ch: Character) {
    let jamo: Character
    if isShifted, let shifted = HANGUL_SHIFT_MAP[ch] {
      jamo = shifted
    } else if let hangul = HANGUL_MAP[ch] {
      jamo = hangul
    } else {
      flushHangul()
      textDocumentProxy.insertText(String(ch))
      return
    }

    let result = automata.input(jamo)

    if composingChar != nil {
      textDocumentProxy.deleteBackward()
      composingChar = nil
    }
    if !result.commit.isEmpty { textDocumentProxy.insertText(result.commit) }
    if let current = result.current {
      textDocumentProxy.insertText(String(current))
      composingChar = current
    }
  }

  private func flushHangul() {
    guard isHangul else { return }
    let committed = automata.flush()
    if composingChar != nil {
      textDocumentProxy.deleteBackward()
      composingChar = nil
    }
    if !committed.isEmpty { textDocumentProxy.insertText(committed) }
  }

  private func rebuildKeyboard() {
    buildKeyboard()
  }
}
