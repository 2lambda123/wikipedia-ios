import Foundation
import UIKit
import WMF

protocol TalkPageCellDelegate: AnyObject {
    func userDidTapDisclosureButton(cellViewModel: TalkPageCellViewModel?, cell: TalkPageCell)
    func userDidTapSubscribeButton(cellViewModel: TalkPageCellViewModel?, cell: TalkPageCell)
}

protocol TalkPageCellReplyDelegate: AnyObject {
    func tappedReply(commentViewModel: TalkPageCellCommentViewModel)
}

final class TalkPageCell: UICollectionViewCell {

    // MARK: - Properties

    static let reuseIdentifier = "TalkPageCell"

    weak var viewModel: TalkPageCellViewModel?
    weak var delegate: TalkPageCellDelegate?
    weak var replyDelegate: TalkPageCellReplyDelegate?

    // MARK: - UI Elements

    lazy var rootContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.masksToBounds = true
        view.layer.cornerCurve = .continuous
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1.0
        return view
    }()

    lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fill
        return stackView
    }()

    lazy var topicView: TalkPageCellTopicView = TalkPageCellTopicView()
    lazy var disclosureRow: TalkPageCellDisclosureRow = TalkPageCellDisclosureRow()
    lazy var commentView = TalkPageCellCommentView()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        viewModel = nil
        delegate = nil
        disclosureRow.disclosureButton.removeTarget(nil, action: nil, for: .allEvents)
        disclosureRow.subscribeButton.removeTarget(nil, action: nil, for: .allEvents)
    }

    func setup() {
        contentView.addSubview(rootContainer)
        rootContainer.addSubview(stackView)
        
        let rootContainerBottomConstraint = rootContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        rootContainerBottomConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            rootContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            rootContainerBottomConstraint,
            rootContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rootContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stackView.topAnchor.constraint(equalTo: rootContainer.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: rootContainer.bottomAnchor, constant: -12),
            stackView.leadingAnchor.constraint(equalTo: rootContainer.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: rootContainer.trailingAnchor, constant: -12)
        ])

        stackView.addArrangedSubview(disclosureRow)
        stackView.addArrangedSubview(topicView)
    }

    // MARK: - Configure

    func configure(viewModel: TalkPageCellViewModel) {
        self.viewModel = viewModel

        disclosureRow.configure(viewModel: viewModel)
        topicView.configure(viewModel: viewModel)

        let comments: [UIView] = stackView.arrangedSubviews.filter { view in view is TalkPageCellCommentView || view is TalkPageCellCommentSeparator }
        stackView.arrangedSubviews.forEach { view in
            if comments.contains(view) {
                view.removeFromSuperview()
            }
        }

        for commentViewModel in viewModel.replies {
            let separator = TalkPageCellCommentSeparator()
            let commentView = TalkPageCellCommentView()
            commentView.replyDelegate = replyDelegate
            commentView.configure(viewModel: commentViewModel)

            commentView.isHidden = !viewModel.isThreadExpanded
            separator.isHidden = !viewModel.isThreadExpanded

            stackView.addArrangedSubview(separator)
            stackView.addArrangedSubview(commentView)
        }

        disclosureRow.disclosureButton.addTarget(self, action: #selector(userDidTapDisclosureButton), for: .primaryActionTriggered)
        disclosureRow.subscribeButton.addTarget(self, action: #selector(userDidTapSubscribeButton), for: .primaryActionTriggered)
        topicView.replyButton.addTarget(self, action: #selector(userDidTapLeadReply), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc func userDidTapDisclosureButton() {
        delegate?.userDidTapDisclosureButton(cellViewModel: viewModel, cell: self)
    }

    @objc func userDidTapSubscribeButton() {
        delegate?.userDidTapSubscribeButton(cellViewModel: viewModel, cell: self)
    }
    
    @objc func userDidTapLeadReply() {
        
        guard let commentViewModel = viewModel?.leadComment else {
            return
        }
        
        replyDelegate?.tappedReply(commentViewModel: commentViewModel)
    }
}

// MARK: - Themeable

extension TalkPageCell: Themeable {

    func apply(theme: Theme) {
        rootContainer.backgroundColor = theme.colors.paperBackground
        rootContainer.layer.borderColor = theme.colors.border.cgColor

        stackView.arrangedSubviews.forEach { ($0 as? Themeable)?.apply(theme: theme) }
    }

}
