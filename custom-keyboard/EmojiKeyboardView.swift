import UIKit

protocol CustomKeyboardViewDelegate: AnyObject {
  func customKeyboardView(_ view: CustomKeyboardView, didSelectCustom custom: String)
  func customKeyboardViewDidBeginBackspace(_ view: CustomKeyboardView)
  func customKeyboardViewDidEndBackspace(_ view: CustomKeyboardView)
}

final class CustomKeyboardView: UIView, UICollectionViewDataSource,
  UICollectionViewDelegateFlowLayout
{

  weak var delegate: CustomKeyboardViewDelegate?

  private var collectionView: UICollectionView!
  private var dockScrollView: UIScrollView!
  private var dockStackView: UIStackView!
  private let emptyStateLabel = UILabel()

  private let provider = EmojiProvider.shared
  private let isPad = UIDevice.current.userInterfaceIdiom == .pad
  private let palette: KeyboardThemePalette

  /// 가용 폭 기준으로 이모지 셀 한 변 길이를 산출(아이패드 등 넓은 화면에서 셀이 과하게 커지지 않도록).
  /// 목표 셀 폭 ~52pt, 최소 8열을 유지한다.
  private var emojiCellSide: CGFloat {
    let ref =
      (collectionView?.bounds.width ?? 0) > 0 ? collectionView.bounds.width : self.bounds.width
    guard ref > 0 else { return 0 }
    let columns = max(8, Int(ref / 52))
    return ref / CGFloat(columns)
  }

  init(palette: KeyboardThemePalette) {
    self.palette = palette
    super.init(frame: .zero)
    provider.loadIfNeeded(retryOnFailure: true)
    setupView()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupView() {
    backgroundColor = palette.emojiBackground
    self.layer.cornerRadius = 12
    self.clipsToBounds = true

    // 1. 독 컨테이너 설정 (카테고리 바)
    let dockContainer = UIView()
    dockContainer.translatesAutoresizingMaskIntoConstraints = false
    addSubview(dockContainer)

    dockStackView = UIStackView()
    dockStackView.axis = .horizontal
    dockStackView.distribution = .fill
    dockStackView.spacing = 18
    dockStackView.translatesAutoresizingMaskIntoConstraints = false

    dockScrollView = UIScrollView()
    dockScrollView.showsHorizontalScrollIndicator = false
    dockScrollView.translatesAutoresizingMaskIntoConstraints = false
    dockContainer.addSubview(dockScrollView)
    dockScrollView.addSubview(dockStackView)

    // 글래스모피즘용 프로스트 블러 스타일
    let glassBlurStyle: UIBlurEffect.Style = .systemThinMaterialDark
    let glassBorderColor = palette.emojiBorder.cgColor

    // 하단 카테고리 퀵바 배경: 프로스트 글래스
    let dockBg = UIVisualEffectView(effect: UIBlurEffect(style: glassBlurStyle))
    dockBg.layer.cornerRadius = 10
    dockBg.clipsToBounds = true
    dockBg.layer.borderWidth = 1
    dockBg.layer.borderColor = glassBorderColor
    dockBg.translatesAutoresizingMaskIntoConstraints = false

    let backspaceBtn = AccessibleEmojiButton(type: .system)
    backspaceBtn.setTitle("⌫", for: .normal)
    backspaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: isPad ? 26 : 20, weight: .medium)
    backspaceBtn.setTitleColor(.white, for: .normal)
    backspaceBtn.backgroundColor = .clear
    backspaceBtn.accessibilityLabel = "삭제"
    backspaceBtn.accessibilityTraits.insert(.keyboardKey)
    backspaceBtn.accessibilityActivationHandler = { [weak self] in
      guard let self else { return false }
      self.delegate?.customKeyboardViewDidBeginBackspace(self)
      self.delegate?.customKeyboardViewDidEndBackspace(self)
      return true
    }
    backspaceBtn.addTarget(self, action: #selector(backspaceTouchDown), for: .touchDown)
    backspaceBtn.addTarget(
      self, action: #selector(backspaceTouchUp),
      for: [.touchUpInside, .touchUpOutside, .touchCancel])
    backspaceBtn.translatesAutoresizingMaskIntoConstraints = false

    // 백스페이스 버튼 배경: 프로스트 글래스 (버튼 뒤에 깔아 터치는 버튼이 받음)
    let backspaceBg = UIVisualEffectView(effect: UIBlurEffect(style: glassBlurStyle))
    backspaceBg.isUserInteractionEnabled = false
    backspaceBg.layer.cornerRadius = 10
    backspaceBg.clipsToBounds = true
    backspaceBg.layer.borderWidth = 1
    backspaceBg.layer.borderColor = glassBorderColor
    backspaceBg.translatesAutoresizingMaskIntoConstraints = false

    dockContainer.insertSubview(dockBg, at: 0)
    dockContainer.addSubview(backspaceBtn)
    dockContainer.insertSubview(backspaceBg, belowSubview: backspaceBtn)

    setupDockButtons()

    // 2. 컬렉션 뷰 설정
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .vertical
    layout.minimumInteritemSpacing = 0
    layout.minimumLineSpacing = 0
    layout.sectionHeadersPinToVisibleBounds = true

    collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    collectionView.backgroundColor = .clear
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.isPrefetchingEnabled = false  // [메모리 최적화] 프리페치에 의한 추가 메모리 사용 방지
    collectionView.register(CustomCell.self, forCellWithReuseIdentifier: "CustomCell")
    collectionView.register(
      CustomHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: "CustomHeader")
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(collectionView)

    emptyStateLabel.text =
      provider.loadingState == .failed
      ? "이모지를 불러오지 못했어요. 키보드를 다시 열어 주세요."
      : "표시할 이모지가 없어요."
    emptyStateLabel.font = .systemFont(ofSize: 14, weight: .medium)
    emptyStateLabel.textColor = palette.specialKeyText
    emptyStateLabel.textAlignment = .center
    emptyStateLabel.numberOfLines = 0
    emptyStateLabel.isHidden = !provider.categories.isEmpty
    emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
    addSubview(emptyStateLabel)

    // 4. Long Press Gesture 추가
    let longPress = UILongPressGestureRecognizer(
      target: self, action: #selector(handleLongPress(_:)))
    longPress.minimumPressDuration = 0.4
    collectionView.addGestureRecognizer(longPress)

    NSLayoutConstraint.activate([
      dockContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
      dockContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
      dockContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
      dockContainer.heightAnchor.constraint(equalToConstant: isPad ? 50 : 38),

      backspaceBtn.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor),
      backspaceBtn.topAnchor.constraint(equalTo: dockContainer.topAnchor),
      backspaceBtn.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
      backspaceBtn.widthAnchor.constraint(equalToConstant: isPad ? 64 : 45),

      backspaceBg.leadingAnchor.constraint(equalTo: backspaceBtn.leadingAnchor),
      backspaceBg.trailingAnchor.constraint(equalTo: backspaceBtn.trailingAnchor),
      backspaceBg.topAnchor.constraint(equalTo: backspaceBtn.topAnchor),
      backspaceBg.bottomAnchor.constraint(equalTo: backspaceBtn.bottomAnchor),

      dockScrollView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor),
      dockScrollView.trailingAnchor.constraint(equalTo: backspaceBtn.leadingAnchor, constant: -5),
      dockScrollView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
      dockScrollView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),

      dockStackView.leadingAnchor.constraint(
        equalTo: dockScrollView.contentLayoutGuide.leadingAnchor, constant: 5),
      dockStackView.trailingAnchor.constraint(
        equalTo: dockScrollView.contentLayoutGuide.trailingAnchor, constant: -5),
      dockStackView.topAnchor.constraint(equalTo: dockScrollView.contentLayoutGuide.topAnchor),
      dockStackView.bottomAnchor.constraint(
        equalTo: dockScrollView.contentLayoutGuide.bottomAnchor),
      dockStackView.heightAnchor.constraint(equalTo: dockScrollView.heightAnchor),

      dockBg.leadingAnchor.constraint(equalTo: dockScrollView.leadingAnchor),
      dockBg.trailingAnchor.constraint(equalTo: dockScrollView.trailingAnchor),
      dockBg.topAnchor.constraint(equalTo: dockScrollView.topAnchor),
      dockBg.bottomAnchor.constraint(equalTo: dockScrollView.bottomAnchor),

      collectionView.topAnchor.constraint(equalTo: topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: dockContainer.topAnchor, constant: -5),

      emptyStateLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
      emptyStateLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
      emptyStateLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: collectionView.leadingAnchor, constant: 24),
      emptyStateLabel.trailingAnchor.constraint(
        lessThanOrEqualTo: collectionView.trailingAnchor, constant: -24),
    ])

    collectionView.reloadData()
  }

  private func setupDockButtons() {
    for view in dockStackView.arrangedSubviews {
      view.removeFromSuperview()
    }

    for (index, category) in provider.categories.enumerated() {
      var config = UIButton.Configuration.plain()
      var titleAttr = AttributeContainer()
      titleAttr.font = UIFont.systemFont(ofSize: isPad ? 26 : 20)
      config.attributedTitle = AttributedString(category.icon, attributes: titleAttr)
      config.baseForegroundColor = palette.specialKeyText
      config.contentInsets = NSDirectionalEdgeInsets(
        top: 0, leading: isPad ? 14 : 10, bottom: 0, trailing: isPad ? 14 : 10)  // 터치 영역 확보

      let btn = UIButton(configuration: config)
      btn.tag = index
      btn.accessibilityLabel = "\(category.title) 이모지"
      btn.accessibilityTraits = .button
      btn.addTarget(self, action: #selector(dockButtonTapped(_:)), for: .touchUpInside)
      dockStackView.addArrangedSubview(btn)
    }
  }

  private var currentPopup: CustomVariationPopup?

  @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    let pointInCollectionView = gesture.location(in: collectionView)
    let pointInView = gesture.location(in: self)

    switch gesture.state {
    case .began:
      guard let indexPath = collectionView.indexPathForItem(at: pointInCollectionView),
        let cell = collectionView.cellForItem(at: indexPath) as? CustomCell,
        let custom = cell.label.text
      else { return }

      if EmojiProvider.shared.supportsSkinTone(custom) {
        showVariationPopup(for: custom, at: cell)
        updateVariationSelection(at: pointInView)
      }

    case .changed:
      if currentPopup != nil {
        updateVariationSelection(at: pointInView)
      }

    case .ended:
      if let popup = currentPopup, let selectedCustom = popup.getSelectedCustom() {
        selectCustom(selectedCustom)
      }
      hideVariationPopup()

    case .cancelled, .failed:
      hideVariationPopup()

    default:
      break
    }
  }

  private func updateVariationSelection(at pointInView: CGPoint) {
    guard let popup = currentPopup else { return }

    let localPoint = convert(pointInView, to: popup)

    let stackView = popup.subviews.compactMap { $0 as? UIStackView }.first
    let itemCount = stackView?.arrangedSubviews.count ?? 1
    let itemWidth = popup.bounds.width / CGFloat(max(1, itemCount))

    guard itemWidth > 0 else { return }

    var index = Int(localPoint.x / itemWidth)
    let maxIndex =
      (popup.subviews.compactMap { $0 as? UIStackView }.first?.arrangedSubviews.count ?? 1) - 1

    if index < 0 { index = 0 }
    if index > maxIndex { index = maxIndex }

    if popup.selectedIndex != index {
      popup.updateSelection(at: index)
    }
  }

  private func hideVariationPopup() {
    currentPopup?.removeFromSuperview()
    currentPopup = nil
  }

  private func showVariationPopup(for custom: String, at cell: UICollectionViewCell) {
    hideVariationPopup()

    guard let superview = self.superview else { return }

    let variations = EmojiProvider.shared.getVariations(for: custom)
    let popup = CustomVariationPopup(variations: variations)
    popup.translatesAutoresizingMaskIntoConstraints = false
    superview.addSubview(popup)

    let cellFrameInSuperview = cell.convert(cell.bounds, to: superview)
    let popupWidth = CGFloat(variations.count * 46 + 16)

    let centerXConstraint = popup.centerXAnchor.constraint(
      equalTo: superview.leadingAnchor, constant: cellFrameInSuperview.midX)
    centerXConstraint.priority = .defaultHigh

    NSLayoutConstraint.activate([
      popup.bottomAnchor.constraint(
        equalTo: superview.topAnchor, constant: cellFrameInSuperview.minY - 12),
      centerXConstraint,
      popup.leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor, constant: 8),
      popup.trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor, constant: -8),
      popup.widthAnchor.constraint(equalToConstant: popupWidth),
      popup.heightAnchor.constraint(equalToConstant: 52),
    ])

    currentPopup = popup
    superview.layoutIfNeeded()
    popup.updateSelection(at: 0)
  }

  @objc private func dockButtonTapped(_ sender: UIButton) {
    KeyboardHaptics.shared.playKeyPress()
    let section = sender.tag
    let indexPath = IndexPath(item: 0, section: section)

    let headerHeight: CGFloat = 30

    if collectionView.numberOfSections > section
      && collectionView.numberOfItems(inSection: section) > 0
    {
      if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
        var targetY = attributes.frame.origin.y - headerHeight

        let maxOffsetY = collectionView.contentSize.height - collectionView.bounds.height
        if targetY > maxOffsetY { targetY = maxOffsetY }
        if targetY < 0 { targetY = 0 }

        collectionView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
      }
    }
  }

  @objc private func backspaceTouchDown() {
    delegate?.customKeyboardViewDidBeginBackspace(self)
  }

  @objc private func backspaceTouchUp() {
    delegate?.customKeyboardViewDidEndBackspace(self)
  }

  // MARK: - UICollectionViewDataSource

  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return provider.categories.count
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int)
    -> Int
  {
    return provider.categories[section].emojis.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell
  {
    guard
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "CustomCell", for: indexPath) as? CustomCell
    else {
      assertionFailure("CustomCell registration mismatch")
      return UICollectionViewCell()
    }
    cell.label.text = provider.categories[indexPath.section].emojis[indexPath.item]
    cell.label.textColor = .white
    // 셀 크기에 맞춰 이모지 글자 크기 조정 (아이패드 등 큰 셀 대응)
    let side = emojiCellSide
    if side > 0 { cell.label.font = .systemFont(ofSize: floor(side * 0.62)) }
    cell.isAccessibilityElement = true
    cell.accessibilityLabel = cell.label.text
    cell.accessibilityTraits = [.button, .keyboardKey]
    return cell
  }

  func collectionView(
    _ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String,
    at indexPath: IndexPath
  ) -> UICollectionReusableView {
    guard
      let header = collectionView.dequeueReusableSupplementaryView(
        ofKind: kind, withReuseIdentifier: "CustomHeader", for: indexPath) as? CustomHeaderView
    else {
      assertionFailure("CustomHeader registration mismatch")
      return UICollectionReusableView()
    }
    header.label.text = provider.categories[indexPath.section].title
    header.label.textColor = UIColor(white: 1.0, alpha: 0.9)
    header.backgroundColor = .clear
    header.applyGlass(palette: palette)

    return header
  }

  // MARK: - UICollectionViewDelegateFlowLayout

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath
  ) -> CGSize {
    let side = emojiCellSide
    return CGSize(width: side, height: side)
  }

  func collectionView(
    _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
    referenceSizeForHeaderInSection section: Int
  ) -> CGSize {
    let width = collectionView.bounds.width > 0 ? collectionView.bounds.width : self.bounds.width
    return CGSize(width: width, height: 30)
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let custom = provider.categories[indexPath.section].emojis[indexPath.item]
    selectCustom(custom)
  }

  private func selectCustom(_ custom: String) {
    let hadRecentBefore = !provider.recentEmojis.isEmpty
    provider.addRecentEmoji(custom)
    let hasRecentNow = !provider.recentEmojis.isEmpty

    delegate?.customKeyboardView(self, didSelectCustom: custom)

    if !hadRecentBefore && hasRecentNow {
      setupDockButtons()
      collectionView.reloadData()
    } else {
      UIView.performWithoutAnimation {
        collectionView.reloadSections(IndexSet(integer: 0))
      }
    }
  }

  override func removeFromSuperview() {
    hideVariationPopup()
    delegate?.customKeyboardViewDidEndBackspace(self)
    super.removeFromSuperview()
  }
}

private final class CustomCell: UICollectionViewCell {
  let label = UILabel()
  override init(frame: CGRect) {
    super.init(frame: frame)
    label.font = UIFont.systemFont(ofSize: 32)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
    ])
  }
  required init?(coder: NSCoder) { fatalError() }
}

private final class AccessibleEmojiButton: UIButton {
  var accessibilityActivationHandler: (() -> Bool)?

  override func accessibilityActivate() -> Bool {
    accessibilityActivationHandler?() ?? super.accessibilityActivate()
  }
}

private final class CustomHeaderView: UICollectionReusableView {
  let label = UILabel()
  private let blurView = UIVisualEffectView()
  private let hairline = UIView()
  override init(frame: CGRect) {
    super.init(frame: frame)
    blurView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(blurView)
    hairline.translatesAutoresizingMaskIntoConstraints = false
    addSubview(hairline)
    label.font = UIFont.boldSystemFont(ofSize: 14)
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
    NSLayoutConstraint.activate([
      blurView.topAnchor.constraint(equalTo: topAnchor),
      blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
      blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
      hairline.leadingAnchor.constraint(equalTo: leadingAnchor),
      hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
      hairline.bottomAnchor.constraint(equalTo: bottomAnchor),
      hairline.heightAnchor.constraint(equalToConstant: 0.5),
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
  required init?(coder: NSCoder) { fatalError() }

  /// 카테고리 이름 헤더에 프로스트 글래스 + 하단 헤어라인 적용
  func applyGlass(palette: KeyboardThemePalette) {
    blurView.effect = UIBlurEffect(style: .systemChromeMaterialDark)
    hairline.backgroundColor = palette.emojiBorder
  }
}
