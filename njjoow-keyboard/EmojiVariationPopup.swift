import UIKit

protocol EmojiVariationPopupDelegate: AnyObject {
    func emojiVariationPopup(_ popup: EmojiVariationPopup, didSelectEmoji emoji: String)
}

class EmojiVariationPopup: UIView {
    weak var delegate: EmojiVariationPopupDelegate?
    private let variations: [String]
    private let stackView = UIStackView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    
    private var labels: [UILabel] = []
    private(set) var selectedIndex: Int = -1
    
    init(variations: [String], isDarkMode: Bool) {
        self.variations = variations
        super.init(frame: .zero)
        setupView(isDarkMode: isDarkMode)
    }
    
    required init?(coder: NSCoder) { nil }
    
    private func setupView(isDarkMode: Bool) {
        layer.cornerRadius = 20
        layer.masksToBounds = false // 그림자를 위해 false
        
        // 블러 배경
        blurView.layer.cornerRadius = 20
        blurView.layer.masksToBounds = true
        addSubview(blurView)
        
        // 스택 뷰 설정
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
        
        // 이모지 레이블 생성
        for emoji in variations {
            let container = UIView()
            container.layer.cornerRadius = 14
            container.layer.masksToBounds = true
            
            let lbl = UILabel()
            lbl.text = emoji
            lbl.font = .systemFont(ofSize: 26)
            lbl.textAlignment = .center
            lbl.translatesAutoresizingMaskIntoConstraints = false
            
            container.addSubview(lbl)
            NSLayoutConstraint.activate([
                lbl.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                lbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                container.widthAnchor.constraint(equalToConstant: 44),
                container.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            stackView.addArrangedSubview(container)
            labels.append(lbl)
        }
        
        // 그림자 효과
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
    }
    
    /// 지정된 인덱스의 이모지를 하이라이트합니다.
    func updateSelection(at index: Int) {
        guard index != selectedIndex else { return }
        selectedIndex = index
        
        for (i, label) in labels.enumerated() {
            if let container = label.superview {
                if i == index {
                    container.backgroundColor = UIColor.white.withAlphaComponent(0.3)
                    label.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                } else {
                    container.backgroundColor = .clear
                    label.transform = .identity
                }
            }
        }
    }
    
    /// 현재 선택된 이모지를 반환합니다.
    func getSelectedEmoji() -> String? {
        guard selectedIndex >= 0 && selectedIndex < variations.count else { return nil }
        return variations[selectedIndex]
    }
}
