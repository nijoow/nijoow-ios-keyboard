import UIKit

protocol CustomKeyboardViewDelegate: AnyObject {
    func customKeyboardView(_ view: CustomKeyboardView, didSelectCustom custom: String)
    func customKeyboardViewDidTapBackspace(_ view: CustomKeyboardView)
}

class CustomKeyboardView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: CustomKeyboardViewDelegate?
    
    private var collectionView: UICollectionView!
    private var dockScrollView: UIScrollView!
    private var dockStackView: UIStackView!
    
    private let provider = EmojiProvider.shared
    private let isDarkMode: Bool
    
    init(isDarkMode: Bool) {
        self.isDarkMode = isDarkMode
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    private func setupView() {
        if isDarkMode {
            self.backgroundColor = UIColor(red: 0.03, green: 0.03, blue: 0.03, alpha: 0.96)
        } else {
            self.backgroundColor = UIColor(red: 0.88, green: 0.89, blue: 0.92, alpha: 0.96)
        }
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
        
        let dockBg = UIView()
        dockBg.backgroundColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.08) : UIColor(white: 0.0, alpha: 0.08)
        dockBg.layer.cornerRadius = 10
        dockBg.translatesAutoresizingMaskIntoConstraints = false
        
        let backspaceBtn = UIButton(type: .system)
        backspaceBtn.setTitle("⌫", for: .normal)
        backspaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        backspaceBtn.setTitleColor(isDarkMode ? .white : .black, for: .normal)
        backspaceBtn.backgroundColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.12) : UIColor(white: 0.0, alpha: 0.12)
        backspaceBtn.layer.cornerRadius = 10
        backspaceBtn.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        backspaceBtn.translatesAutoresizingMaskIntoConstraints = false
        
        dockContainer.insertSubview(dockBg, at: 0)
        dockContainer.addSubview(backspaceBtn)
        
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
        collectionView.isPrefetchingEnabled = false // [메모리 최적화] 프리페치에 의한 추가 메모리 사용 방지
        collectionView.register(CustomCell.self, forCellWithReuseIdentifier: "CustomCell")
        collectionView.register(CustomHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "CustomHeader")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        
        // 4. Long Press Gesture 추가
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.4
        collectionView.addGestureRecognizer(longPress)
        
        NSLayoutConstraint.activate([
            dockContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            dockContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            dockContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            dockContainer.heightAnchor.constraint(equalToConstant: 38),
            
            backspaceBtn.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor),
            backspaceBtn.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            backspaceBtn.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            backspaceBtn.widthAnchor.constraint(equalToConstant: 45),
            
            dockScrollView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor),
            dockScrollView.trailingAnchor.constraint(equalTo: backspaceBtn.leadingAnchor, constant: -5),
            dockScrollView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            dockScrollView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            
            dockStackView.leadingAnchor.constraint(equalTo: dockScrollView.contentLayoutGuide.leadingAnchor, constant: 5),
            dockStackView.trailingAnchor.constraint(equalTo: dockScrollView.contentLayoutGuide.trailingAnchor, constant: -5),
            dockStackView.topAnchor.constraint(equalTo: dockScrollView.contentLayoutGuide.topAnchor),
            dockStackView.bottomAnchor.constraint(equalTo: dockScrollView.contentLayoutGuide.bottomAnchor),
            dockStackView.heightAnchor.constraint(equalTo: dockScrollView.heightAnchor),
            
            dockBg.leadingAnchor.constraint(equalTo: dockScrollView.leadingAnchor),
            dockBg.trailingAnchor.constraint(equalTo: dockScrollView.trailingAnchor),
            dockBg.topAnchor.constraint(equalTo: dockScrollView.topAnchor),
            dockBg.bottomAnchor.constraint(equalTo: dockScrollView.bottomAnchor),
            
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: dockContainer.topAnchor, constant: -5)
        ])
        
        collectionView.reloadData()
    }
    
    private func setupDockButtons() {
        dockStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, category) in provider.categories.enumerated() {
            var config = UIButton.Configuration.plain()
            config.title = category.icon
            config.baseForegroundColor = isDarkMode ? .white : .black
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10) // 터치 영역 확보
            
            let btn = UIButton(configuration: config)
            btn.tag = index
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
                  let custom = cell.label.text else { return }
            
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
        let maxIndex = (popup.subviews.compactMap { $0 as? UIStackView }.first?.arrangedSubviews.count ?? 1) - 1
        
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
        let popup = CustomVariationPopup(variations: variations, isDarkMode: isDarkMode)
        popup.translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(popup)
        
        let cellFrameInSuperview = cell.convert(cell.bounds, to: superview)
        let popupWidth = CGFloat(variations.count * 46 + 16)
        
        let centerXConstraint = popup.centerXAnchor.constraint(equalTo: superview.leadingAnchor, constant: cellFrameInSuperview.midX)
        centerXConstraint.priority = .defaultHigh 
        
        NSLayoutConstraint.activate([
            popup.bottomAnchor.constraint(equalTo: superview.topAnchor, constant: cellFrameInSuperview.minY - 12),
            centerXConstraint,
            popup.leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor, constant: 8),
            popup.trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor, constant: -8),
            popup.widthAnchor.constraint(equalToConstant: popupWidth),
            popup.heightAnchor.constraint(equalToConstant: 52)
        ])
        
        currentPopup = popup
    }
    
    @objc private func dockButtonTapped(_ sender: UIButton) {
        let section = sender.tag
        let indexPath = IndexPath(item: 0, section: section)
        
        let headerHeight: CGFloat = 30
        
        if collectionView.numberOfSections > section && collectionView.numberOfItems(inSection: section) > 0 {
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
                var targetY = attributes.frame.origin.y - headerHeight
                
                let maxOffsetY = collectionView.contentSize.height - collectionView.bounds.height
                if targetY > maxOffsetY { targetY = maxOffsetY }
                if targetY < 0 { targetY = 0 }
                
                collectionView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
            }
        }
    }
    
    @objc private func backspaceTapped() {
        delegate?.customKeyboardViewDidTapBackspace(self)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return provider.categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return provider.categories[section].emojis.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CustomCell", for: indexPath) as! CustomCell
        cell.label.text = provider.categories[indexPath.section].emojis[indexPath.item]
        cell.label.textColor = isDarkMode ? .white : .black
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "CustomHeader", for: indexPath) as! CustomHeaderView
        header.label.text = provider.categories[indexPath.section].title
        header.label.textColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.9) : .black
        header.backgroundColor = isDarkMode
            ? UIColor(white: 0.15, alpha: 0.85)
            : UIColor(white: 0.95, alpha: 0.85)
        
        return header
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let referenceWidth = collectionView.bounds.width > 0 ? collectionView.bounds.width : self.bounds.width
        let width = referenceWidth / 8
        return CGSize(width: width, height: width) 
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
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
}

class CustomCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = UIFont.systemFont(ofSize: 32)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

class CustomHeaderView: UICollectionReusableView {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

extension CustomKeyboardView: CustomVariationPopupDelegate {
    func customVariationPopup(_ popup: CustomVariationPopup, didSelectCustom custom: String) {
        selectCustom(custom)
        
        popup.removeFromSuperview()
        currentPopup = nil
    }
}
