import UIKit

final class TalkPageView: SetupView {

    // MARK: - Private Properties
    
    private var topicGroupLayout: UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return layout
    }

    // MARK: - UI Elements

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: topicGroupLayout)
        collectionView.register(TalkPageCell.self, forCellWithReuseIdentifier: TalkPageCell.reuseIdentifier)
        collectionView.alwaysBounceVertical = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    // MARK: - Lifecycle

    override func setup() {
        addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

}

// MARK: - Themeable

extension TalkPageView: Themeable {

    func apply(theme: Theme) {
        // TODO: Replace these once new theme colors are added/refreshed in the app
        let baseBackground: UIColor!
        switch theme {
        case .light:
            baseBackground = UIColor.wmf_colorWithHex(0xF8F9FA)
        case .sepia:
            baseBackground = UIColor.wmf_colorWithHex(0xF0E6D6)
        case .dark:
            baseBackground = UIColor.wmf_colorWithHex(0x202122)
        case .black:
            baseBackground = UIColor.wmf_colorWithHex(0x202122)
        default:
            baseBackground = UIColor.wmf_colorWithHex(0xF8F9FA)
        }

        collectionView.backgroundColor = baseBackground
    }

}
