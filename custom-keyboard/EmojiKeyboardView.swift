import UIKit

protocol CustomKeyboardViewDelegate: AnyObject {
    func customKeyboardView(_ view: CustomKeyboardView, didSelectCustom custom: String)
    func customKeyboardViewDidTapBackspace(_ view: CustomKeyboardView)
    func customKeyboardViewDidRequestHaptic(_ view: CustomKeyboardView)
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
        // [최적화] 여기서 reloadData()나 invalidateLayout()을 호출하면 
        // 팝업이 뜰 때마다 수천 개의 셀을 다시 그리게 되어 메모리 크래시가 발생합니다.
        // 오토레이아웃으로 제약 조건만 업데이트되도록 합니다.
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
        dockStackView.distribution = .fill
        dockStackView.spacing = 18 // [개선] 버튼 사이의 간격을 넓혀 터치 오인식 방지
        dockStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // [개선] 스크롤 가능한 카테고리 바 구현
        dockScrollView = UIScrollView()
        dockScrollView.showsHorizontalScrollIndicator = false
        dockScrollView.translatesAutoresizingMaskIntoConstraints = false
        dockContainer.addSubview(dockScrollView)
        dockScrollView.addSubview(dockStackView)
        
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
        
        dockContainer.insertSubview(dockBg, at: 0)
        dockContainer.addSubview(backspaceBtn)
        
        setupDockButtons()
        
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
        
        // [최적화] 초기화 시점에 데이터를 로드합니다.
        collectionView.reloadData()
    }
    
    /// [고도화] 최근 사용 탭을 포함하여 도크 버튼들을 구성합니다.
    private func setupDockButtons() {
        // 기존 뷰 제거
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
                delegate?.customKeyboardViewDidRequestHaptic(self)
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
        
        // [수정] 팝업이 이제 superview(최상위 뷰)에 있으므로, 
        // 현재 뷰(self)의 좌표를 팝업의 좌표계로 정확히 변환해야 합니다.
        let localPoint = convert(pointInView, to: popup)
        
        let stackView = popup.subviews.compactMap { $0 as? UIStackView }.first
        let itemCount = stackView?.arrangedSubviews.count ?? 1
        let itemWidth = popup.bounds.width / CGFloat(max(1, itemCount))
        
        // [안전 장치] 레이아웃이 미처 잡히지 않아 itemWidth가 0인 경우 크래시 방지
        guard itemWidth > 0 else { return }
        
        var index = Int(localPoint.x / itemWidth)
        let maxIndex = (popup.subviews.compactMap { $0 as? UIStackView }.first?.arrangedSubviews.count ?? 1) - 1
        
        if index < 0 { index = 0 }
        if index > maxIndex { index = maxIndex }
        
        if popup.selectedIndex != index {
            delegate?.customKeyboardViewDidRequestHaptic(self)
            popup.updateSelection(at: index)
        }
    }
    
    private func hideVariationPopup() {
        currentPopup?.removeFromSuperview()
        currentPopup = nil
    }
    
    private func showVariationPopup(for custom: String, at cell: UICollectionViewCell) {
        hideVariationPopup()
        
        // [수정] 팝업이 키보드 영역 밖으로(상단으로) 나갈 수 있도록 최상위 뷰에 추가합니다.
        guard let superview = self.superview else { return }
        
        let variations = EmojiProvider.shared.getVariations(for: custom)
        let popup = CustomVariationPopup(variations: variations, isDarkMode: isDarkMode)
        popup.translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(popup)
        
        // 셀의 위치를 최상위 뷰 기준으로 변환합니다.
        let cellFrameInSuperview = cell.convert(cell.bounds, to: superview)
        let popupWidth = CGFloat(variations.count * 46 + 16)
        
        // 제약 조건 설정 (Edge Safety 적용)
        let centerXConstraint = popup.centerXAnchor.constraint(equalTo: superview.leadingAnchor, constant: cellFrameInSuperview.midX)
        centerXConstraint.priority = .defaultHigh // 중앙 정렬보다 화면 이탈 방지를 더 우선시함
        
        NSLayoutConstraint.activate([
            popup.bottomAnchor.constraint(equalTo: superview.topAnchor, constant: cellFrameInSuperview.minY - 12),
            centerXConstraint,
            // [Edge Safety] 화면 좌우 끝에서 8pt 이상의 여백을 강제함
            popup.leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor, constant: 8),
            popup.trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor, constant: -8),
            popup.widthAnchor.constraint(equalToConstant: popupWidth),
            popup.heightAnchor.constraint(equalToConstant: 52)
        ])
        
        currentPopup = popup
        delegate?.customKeyboardViewDidRequestHaptic(self)
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
                delegate?.customKeyboardViewDidRequestHaptic(self)
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
        
        // 투명도 있는 배경색 (Glassmorphism 헤더)
        if UIAccessibility.isReduceTransparencyEnabled {
             header.backgroundColor = isDarkMode ? .black : .white
        } else {
             header.backgroundColor = isDarkMode ? UIColor(white: 0.2, alpha: 0.3) : UIColor(white: 1, alpha: 0.4)
             
             // Blur Effect
             // [최적화] 블러 뷰가 이미 존재하는지 체크하고, 없다면 생성합니다.
             if let existingBlur = header.viewWithTag(99) as? UIVisualEffectView {
                 existingBlur.effect = UIBlurEffect(style: isDarkMode ? .dark : .extraLight)
             } else {
                 let blurEffect = UIBlurEffect(style: isDarkMode ? .dark : .extraLight)
                 let blurView = UIVisualEffectView(effect: blurEffect)
                 blurView.tag = 99
                 blurView.alpha = 0.5 // 메모리 및 렌더링 가독성을 위해 투명도 살짝 적용
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
        let custom = provider.categories[indexPath.section].emojis[indexPath.item]
        selectCustom(custom)
    }
    
    private func selectCustom(_ custom: String) {
        // [수정] 최근 이용 기록 업데이트 및 전체 새로고침
        let hadRecentBefore = !provider.recentEmojis.isEmpty
        provider.addRecentEmoji(custom)
        let hasRecentNow = !provider.recentEmojis.isEmpty
        
        delegate?.customKeyboardView(self, didSelectCustom: custom)
        
        // 최근 사용 탭이 처음 생기거나 목록이 바뀌면 UI 업데이트
        if !hadRecentBefore && hasRecentNow {
            setupDockButtons()
            collectionView.reloadData()
        } else {
            // 이미 최근 사용 탭이 있으면 해당 섹션만 새로고침 (애니메이션 없이 조용히)
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
        // 선택된 가변 이모지 입력 및 최근 사용 업데이트
        selectCustom(custom)
        
        // 팝업 제거
        popup.removeFromSuperview()
        currentPopup = nil
    }
}
