import UIKit

protocol EmojiKeyboardViewDelegate: AnyObject {
    func emojiKeyboardView(_ view: EmojiKeyboardView, didSelectEmoji emoji: String)
    func emojiKeyboardViewDidTapBackspace(_ view: EmojiKeyboardView)
    func emojiKeyboardViewDidRequestHaptic(_ view: EmojiKeyboardView)
}

class EmojiKeyboardView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: EmojiKeyboardViewDelegate?
    
    private var collectionView: UICollectionView!
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
        collectionView.collectionViewLayout.invalidateLayout()
        // 사이즈가 결정된 후 데이터를 다시 로드하여 렌더링 보장
        collectionView.reloadData()
    }
    
    private func setupView() {
        // 배경색 설정 (뒤의 버튼들이 보이지 않도록 불투명하게 처리)
        // 키보드 전체의 유리 질감과 어울리도록 짙은 색상 적용
        self.backgroundColor = isDarkMode ? UIColor(white: 0.05, alpha: 1.0) : UIColor(white: 0.9, alpha: 1.0)
        self.layer.cornerRadius = 12
        self.clipsToBounds = true
        
        // 1. Setup dock container (카테고리 바)
        let dockContainer = UIView()
        dockContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dockContainer)
        
        dockStackView = UIStackView()
        dockStackView.axis = .horizontal
        dockStackView.distribution = .fillEqually
        dockStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 메인 키보드의 specialGlassColor와 유사하게 설정
        let dockBg = UIView()
        dockBg.backgroundColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.08) : UIColor(white: 0.2, alpha: 0.05)
        dockBg.layer.cornerRadius = 10
        dockBg.translatesAutoresizingMaskIntoConstraints = false
        
        let backspaceBtn = UIButton(type: .system)
        backspaceBtn.setTitle("⌫", for: .normal)
        backspaceBtn.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        backspaceBtn.setTitleColor(isDarkMode ? .white : .black, for: .normal)
        backspaceBtn.backgroundColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.12) : UIColor(white: 0.0, alpha: 0.1)
        backspaceBtn.layer.cornerRadius = 10
        backspaceBtn.addTarget(self, action: #selector(backspaceTapped), for: .touchUpInside)
        backspaceBtn.translatesAutoresizingMaskIntoConstraints = false
        
        dockContainer.addSubview(dockBg)
        dockContainer.addSubview(dockStackView)
        dockContainer.addSubview(backspaceBtn)
        
        for (index, category) in provider.categories.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(category.icon, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 20)
            btn.tag = index
            btn.addTarget(self, action: #selector(dockButtonTapped(_:)), for: .touchUpInside)
            dockStackView.addArrangedSubview(btn)
        }
        
        // 2. Setup CollectionView
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionHeadersPinToVisibleBounds = true
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: "EmojiCell")
        collectionView.register(EmojiHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "EmojiHeader")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            dockContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            dockContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            dockContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            dockContainer.heightAnchor.constraint(equalToConstant: 38),
            
            backspaceBtn.trailingAnchor.constraint(equalTo: dockContainer.trailingAnchor),
            backspaceBtn.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            backspaceBtn.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            backspaceBtn.widthAnchor.constraint(equalToConstant: 45),
            
            dockStackView.leadingAnchor.constraint(equalTo: dockContainer.leadingAnchor),
            dockStackView.trailingAnchor.constraint(equalTo: backspaceBtn.leadingAnchor, constant: -10),
            dockStackView.topAnchor.constraint(equalTo: dockContainer.topAnchor),
            dockStackView.bottomAnchor.constraint(equalTo: dockContainer.bottomAnchor),
            
            dockBg.leadingAnchor.constraint(equalTo: dockStackView.leadingAnchor),
            dockBg.trailingAnchor.constraint(equalTo: dockStackView.trailingAnchor),
            dockBg.topAnchor.constraint(equalTo: dockStackView.topAnchor),
            dockBg.bottomAnchor.constraint(equalTo: dockStackView.bottomAnchor),
            
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: dockContainer.topAnchor, constant: -5)
        ])
    }
    
    @objc private func dockButtonTapped(_ sender: UIButton) {
        let section = sender.tag
        let indexPath = IndexPath(item: 0, section: section)
        
        let headerHeight: CGFloat = 30
        
        // 해당 섹션에 아이템이 있는지 확인
        if collectionView.numberOfSections > section && collectionView.numberOfItems(inSection: section) > 0 {
            // 아이템의 레이아웃 성질을 가져옴
            if let attributes = collectionView.layoutAttributesForItem(at: indexPath) {
                // 아이템 위치에서 헤더 높이만큼 뺀 지점이 실제 섹션의 시작점
                var targetY = attributes.frame.origin.y - headerHeight
                
                // 컨텐츠 범위를 벗어나지 않도록 제한
                let maxOffsetY = collectionView.contentSize.height - collectionView.bounds.height
                if targetY > maxOffsetY { targetY = maxOffsetY }
                if targetY < 0 { targetY = 0 }
                
                collectionView.setContentOffset(CGPoint(x: 0, y: targetY), animated: true)
                delegate?.emojiKeyboardViewDidRequestHaptic(self)
            }
        }
    }
    
    @objc private func backspaceTapped() {
        delegate?.emojiKeyboardViewDidTapBackspace(self)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return provider.categories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return provider.categories[section].emojis.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath) as! EmojiCell
        cell.label.text = provider.categories[indexPath.section].emojis[indexPath.item]
        cell.label.textColor = isDarkMode ? .white : .black
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "EmojiHeader", for: indexPath) as! EmojiHeaderView
        header.label.text = provider.categories[indexPath.section].title
        header.label.textColor = isDarkMode ? UIColor(white: 1.0, alpha: 0.9) : .black
        
        // 투명도 있는 배경색 (Glassmorphism 헤더)
        if UIAccessibility.isReduceTransparencyEnabled {
             header.backgroundColor = isDarkMode ? .black : .white
        } else {
             header.backgroundColor = isDarkMode ? UIColor(white: 0.2, alpha: 0.3) : UIColor(white: 1, alpha: 0.4)
             
             // Blur Effect
             if header.viewWithTag(99) == nil {
                 let blurEffect = UIBlurEffect(style: isDarkMode ? .dark : .extraLight)
                 let blurView = UIVisualEffectView(effect: blurEffect)
                 blurView.tag = 99
                 blurView.translatesAutoresizingMaskIntoConstraints = false
                 header.insertSubview(blurView, at: 0)
                 NSLayoutConstraint.activate([
                     blurView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
                     blurView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
                     blurView.topAnchor.constraint(equalTo: header.topAnchor),
                     blurView.bottomAnchor.constraint(equalTo: header.bottomAnchor)
                 ])
             }
        }
        
        return header
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let referenceWidth = collectionView.bounds.width > 0 ? collectionView.bounds.width : self.bounds.width
        let width = referenceWidth / 8
        return CGSize(width: width, height: width) // 정사각형 유지
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let width = collectionView.bounds.width > 0 ? collectionView.bounds.width : self.bounds.width
        return CGSize(width: width, height: 30)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = provider.categories[indexPath.section].emojis[indexPath.item]
        delegate?.emojiKeyboardView(self, didSelectEmoji: emoji)
    }
}

class EmojiCell: UICollectionViewCell {
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

class EmojiHeaderView: UICollectionReusableView {
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
