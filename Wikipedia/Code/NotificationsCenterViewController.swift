import UIKit
import WMF
import SwiftUI

@objc
final class NotificationsCenterViewController: ViewController {

    // MARK: - Properties

    var notificationsView: NotificationsCenterView {
        return view as! NotificationsCenterView
    }

    let viewModel: NotificationsCenterViewModel
    
    var didUpdateFiltersCallback: (() -> Void)?
    
    lazy var markAllAsReadButton: UIBarButtonItem = {
        let markAllAsReadText = WMFLocalizedString("notifications-center-mark-all-as-read", value: "Mark all as read", comment: "Toolbar button text in Notifications Center that marks all user notifications as read on the server.")
        return UIBarButtonItem(title: markAllAsReadText, style: .plain, target: self, action: #selector(didTapMarkAllAsReadButton(_:)))
    }()
    
    lazy var filterButton: UIBarButtonItem = {
        return UIBarButtonItem.init(image: filterButtonImageForFiltersEnabled(viewModel.filtersToolbarViewModel.areFiltersEnabled), style: .plain, target: self, action: #selector(didTapFilterButton))
    }()
    
    lazy var inboxButton: UIBarButtonItem = {
        return UIBarButtonItem.init(image: inboxButtonImageForFiltersEnabled(viewModel.filtersToolbarViewModel.areInboxFiltersEnabled), style: .plain, target: self, action: #selector(didTapInboxButton))
    }()
    
    // MARK: Properties - Diffable Data Source
    typealias DataSource = UICollectionViewDiffableDataSource<NotificationsCenterSection, NotificationsCenterCellViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<NotificationsCenterSection, NotificationsCenterCellViewModel>
    private var dataSource: DataSource?
    private let snapshotUpdateQueue = DispatchQueue(label: "org.wikipedia.notificationscenter.snapshotUpdateQueue", qos: .userInteractive)

    // MARK: - Properties - Cell Swipe Actions

    fileprivate struct CellSwipeData {
        var activelyPannedCellIndexPath: IndexPath? // IndexPath of actively panned or open cell
        var activelyPannedCellTranslationX: CGFloat? // translation on x-axis of open cell

        func activeCell(in collectionView: UICollectionView) -> NotificationsCenterCell? {
            guard let activelyPannedCellIndexPath = activelyPannedCellIndexPath else {
                return nil
            }

            return collectionView.cellForItem(at: activelyPannedCellIndexPath) as? NotificationsCenterCell
        }

        mutating func resetActiveData() {
            activelyPannedCellIndexPath = nil
            activelyPannedCellTranslationX = nil
        }
    }

    fileprivate lazy var cellPanGestureRecognizer = UIPanGestureRecognizer()
    fileprivate lazy var cellSwipeData = CellSwipeData()

    // MARK: - Lifecycle

    @objc
    init(theme: Theme, viewModel: NotificationsCenterViewModel) {
        self.viewModel = viewModel
        super.init(theme: theme)
        viewModel.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let notificationsCenterView = NotificationsCenterView(frame: UIScreen.main.bounds)
        notificationsCenterView.addSubheaderTapGestureRecognizer(target: self, action: #selector(tappedEmptyStateSubheader))
        view = notificationsCenterView
        scrollView = notificationsView.collectionView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        notificationsView.apply(theme: theme)

        title = CommonStrings.notificationsCenterTitle
        setupBarButtons()
        
        notificationsView.collectionView.delegate = self
        setupDataSource()
        viewModel.fetchFirstPage()
        
        notificationsView.collectionView.addGestureRecognizer(cellPanGestureRecognizer)
        cellPanGestureRecognizer.addTarget(self, action: #selector(userDidPanCell(_:)))
        cellPanGestureRecognizer.delegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.refreshNotifications(force: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        closeActiveSwipePanelIfNecessary()
    }

    @objc fileprivate func applicationWillResignActive() {
        closeActiveSwipePanelIfNecessary()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            notificationsView.collectionView.reloadData()
        }
    }

	// MARK: - Configuration

    fileprivate func setupBarButtons() {
        enableToolbar()
        setToolbarHidden(false, animated: false)

		navigationItem.rightBarButtonItem = editButtonItem
	}

	// MARK: - Public
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        notificationsView.collectionView.allowsMultipleSelection = editing
        viewModel.updateStateFromEditingModeChange(isEditing: isEditing)
    }


    // MARK: - Themable

    override func apply(theme: Theme) {
        super.apply(theme: theme)

        notificationsView.apply(theme: theme)
        notificationsView.collectionView.reloadData()
    }
}

//MARK: Private

private extension NotificationsCenterViewController {
    
    func setupDataSource() {
        dataSource = DataSource(
        collectionView: notificationsView.collectionView,
        cellProvider: { [weak self] (collectionView, indexPath, cellViewModel) ->
            NotificationsCenterCell? in

            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NotificationsCenterCell.reuseIdentifier, for: indexPath) as? NotificationsCenterCell else {
                return nil
            }
            cell.configure(viewModel: cellViewModel, theme: self.theme)
            cell.delegate = self
            return cell
        })
    }
    
    func applySnapshot(cellViewModels: [NotificationsCenterCellViewModel], animatingDifferences: Bool = true) {
        
        guard let dataSource = dataSource else {
            return
        }
        
        snapshotUpdateQueue.async {
            var snapshot = Snapshot()
            snapshot.appendSections([.main])
            snapshot.appendItems(cellViewModels)
            dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
        }
    }
    
    func configureEmptyState(isEmpty: Bool, subheaderText: String = "", subheaderAttributedString: NSAttributedString? = nil) {
        notificationsView.updateEmptyOverlay(visible: isEmpty, headerText: NotificationsCenterView.EmptyOverlayStrings.noUnreadMessages, subheaderText: subheaderText, subheaderAttributedString: subheaderAttributedString)
        notificationsView.collectionView.isHidden = isEmpty
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = !isEmpty }
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty
    }
    
    /// TODO: Use this to determine selected view models when in editing mode. We will send to NotificationsCenterViewModel for marking as read/unread when
    /// the associated toolbar button is pressed.
    /// - Returns:View models that represent cells in the selected state.
    func selectedCellViewModels() -> [NotificationsCenterCellViewModel] {
        guard let selectedIndexPaths = notificationsView.collectionView.indexPathsForSelectedItems,
        let dataSource = dataSource else {
            return []
        }
        
        let selectedViewModels = selectedIndexPaths.compactMap { dataSource.itemIdentifier(for: $0) }
        return selectedViewModels
    }
    
    func deselectCells() {
        closeActiveSwipePanelIfNecessary()
        notificationsView.collectionView.indexPathsForSelectedItems?.forEach {
            notificationsView.collectionView.deselectItem(at: $0, animated: false)
        }
    }
    
    /// Calls cell configure methods again without instantiating a new cell.
    func reconfigureCells() {
        
        if #available(iOS 15.0, *) {
            snapshotUpdateQueue.async {
                if var snapshot = self.dataSource?.snapshot() {
                    
                    let viewModelsToUpdate = snapshot.itemIdentifiers
                    snapshot.reconfigureItems(viewModelsToUpdate)
                    self.dataSource?.apply(snapshot, animatingDifferences: false)
                }
            }
        } else {
            
            let cellsToReconfigure = notificationsView.collectionView.visibleCells as? [NotificationsCenterCell] ?? []
            
            cellsToReconfigure.forEach { cell in
                cell.configure(theme: theme)
            }
        }
    }
    
    var titleForToolbarTitleView: String? {
        
        guard viewModel.remoteNotificationsController.areFiltersEnabled else {
            return "All notifications"
        }
        
        return "Filtered by:"
    }
    
    var subtitleForToolbarTitleView: (String, String)? {
        
        guard viewModel.remoteNotificationsController.areFiltersEnabled,
              let filterState = viewModel.remoteNotificationsController.filterSavedState else {
            return nil
        }
        
        var readStatusString: String?
        switch filterState.readStatusSetting {
        case .read:
            readStatusString = "Read"
        case .unread:
            readStatusString = "Unread"
        default:
            readStatusString = nil
        }
        
        let typesStringFormat = WMFLocalizedString("notifications-center-num-types-in-filter-format", value:"{{PLURAL:%1$d|%1$d type|%1$d types}}", comment:"Portion of subtitle of notfications center toolbar indicating how many types user has selected in their filter - %1$d is replaced with the number of notification types selected in their filter.")
        let typeTitle = String.localizedStringWithFormat(typesStringFormat, filterState.filterTypeSetting.count)
        let typeStatusString: String? = filterState.filterTypeSetting.count > 0 ? typeTitle : nil
        
        let projectsStringFormat = WMFLocalizedString("notifications-center-num-projects-in-filter-format", value:"{{PLURAL:%1$d|%1$d project|%1$d projects}}", comment:"Portion of subtitle of notfications center toolbar indicating how many projects user has selected in their filter - %1$d is replaced with the number of notification projeccts selected in their filter.")
        let showingInboxProjects = viewModel.remoteNotificationsController.cachedShowingInboxProjects
        
        let projectTitle = String.localizedStringWithFormat(projectsStringFormat, showingInboxProjects.count)
        
        let projectStatusString: String
        if showingInboxProjects.count == 1,
           let project = showingInboxProjects.first {
            projectStatusString = project.projectName(shouldReturnCodedFormat: false)
        } else {
            projectStatusString = projectTitle
        }
        
        let suffix = "in \(projectStatusString)"
        let prefix = [readStatusString, typeStatusString].compactMap { $0 }.joined(separator: " and ")
        
        return ("\(prefix) \(suffix)", prefix)
    }
    
    var attributedStringForToolbarTitleView: NSAttributedString? {
        
        guard let titleForToolbarTitleView = titleForToolbarTitleView else {
            return nil
        }

        let font = UIFont.systemFont(ofSize: 11)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: theme.colors.primaryText
            ]
        
        let mutableAttributedString = NSMutableAttributedString(string: titleForToolbarTitleView)
        mutableAttributedString.setAttributes(titleAttributes, range: NSRange.init(location: 0, length: titleForToolbarTitleView.count))
        
        guard let subtitle = subtitleForToolbarTitleView?.0,
              let subtitleLinkPrefix: String = subtitleForToolbarTitleView?.1 else {
            return mutableAttributedString.copy() as? NSAttributedString
        }
        
        let spacerString = "\n"
        let spacerAttributedString = NSMutableAttributedString(string: spacerString)
        spacerAttributedString.setAttributes(titleAttributes, range: NSRange.init(location: 0, length: spacerString.count))
        mutableAttributedString.append(spacerAttributedString)

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: theme.colors.secondaryText
            ]
        let linkAttributes = [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: theme.colors.link
            ]
        
        let subtitleAttributedString = NSMutableAttributedString(string: subtitle)
        subtitleAttributedString.setAttributes(subtitleAttributes, range: NSRange.init(location: 0, length: subtitle.count))
        
        let linkRange = (subtitle as NSString).range(of: subtitleLinkPrefix)
        
        if linkRange.location != NSNotFound {
            subtitleAttributedString.setAttributes(linkAttributes, range: linkRange)
        }
        
        mutableAttributedString.append(subtitleAttributedString)
        return mutableAttributedString.copy() as? NSAttributedString
        
    }
    
    @objc func tappedToolbarCustomTitleView() {
        presentFiltersViewController()
    }
    
    var customViewForToolbarTitleView: UIView? {
        //TODO: a lot of this logic should come from a view model
        
        let testCustomView = UILabel.init(frame: .zero)
        testCustomView.numberOfLines = 0
        testCustomView.textAlignment = .center
        if viewModel.remoteNotificationsController.areFiltersEnabled {
            testCustomView.isUserInteractionEnabled = true
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tappedToolbarCustomTitleView))
            testCustomView.addGestureRecognizer(tapGestureRecognizer)
        }
        
        switch viewModel.state {
        case .empty(let emptyState):
            switch emptyState {
            case .filters:
                if let attributedString = attributedStringForToolbarTitleView {
                    testCustomView.attributedText = attributedString
                }
                
                return testCustomView
            default:
                return nil
            }
        case .data(_, let dataState):
            switch dataState {
            case .editing:
                return nil
            case .nonEditing:
                if let attributedString = attributedStringForToolbarTitleView {
                    testCustomView.attributedText = attributedString
                }
                
                return testCustomView
            }
        }
    }
    
    func updateToolbar(for state: NotificationsCenterViewModel.State) {
        switch state {
        case .data(_, let dataState):
            switch dataState {
            case .editing(let dataEditingState):
                
                let markButton: UIBarButtonItem
                let markAllAsReadButton = self.markAllAsReadButton
                switch dataEditingState {
                case .noneSelected:
                    markButton = markButtonForNumberOfSelectedMessages(numSelectedMessages: 0)
                    markButton.isEnabled = false
                    markAllAsReadButton.isEnabled = true
                case .oneOrMoreSelected(let numSelected):
                    markButton = markButtonForNumberOfSelectedMessages(numSelectedMessages: numSelected)
                    markButton.isEnabled = true
                    markAllAsReadButton.isEnabled = false
                }
                
                toolbar.items = [
                    markButton,
                    UIBarButtonItem.flexibleSpaceToolbar(),
                    markAllAsReadButton
                ]
            case .nonEditing:
                if let customView = customViewForToolbarTitleView {
                    toolbar.items = [
                        filterButton,
                        UIBarButtonItem.flexibleSpaceToolbar(),
                        UIBarButtonItem.init(customView: customView),
                        UIBarButtonItem.flexibleSpaceToolbar(),
                        inboxButton
                    ]
                } else {
                    toolbar.items = [
                        filterButton,
                        UIBarButtonItem.flexibleSpaceToolbar(),
                        inboxButton
                    ]
                }
            }
        case .empty(let emptyState):
            switch emptyState {
            case .filters:
                if let customView = customViewForToolbarTitleView {
                    toolbar.items = [
                        filterButton,
                        UIBarButtonItem.flexibleSpaceToolbar(),
                        UIBarButtonItem.init(customView: customView),
                        UIBarButtonItem.flexibleSpaceToolbar(),
                        inboxButton
                    ]
                } else {
                    toolbar.items = [
                        filterButton,
                        UIBarButtonItem.flexibleSpaceToolbar(),
                        inboxButton
                    ]
                }
            case .inboxFilters:
                toolbar.items = [
                    filterButton,
                    UIBarButtonItem.flexibleSpaceToolbar(),
                    inboxButton
                ]
            default:
                toolbar.items = []
            }
            
            
        }
    }
    
    func markButtonForNumberOfSelectedMessages(numSelectedMessages: Int) -> UIBarButtonItem {
        let titleFormat = WMFLocalizedString("notifications-center-num-selected-messages-format", value:"{{PLURAL:%1$d|%1$d message|%1$d messages}}", comment:"Title for options menu when choosing \"Mark\" toolbar button in notifications center editing mode - %1$d is replaced with the number of selected notifications.")
        let title = String.localizedStringWithFormat(titleFormat, numSelectedMessages)
        let optionsMenu = UIMenu(title: title, children: [
            UIAction.init(title: CommonStrings.notificationsCenterMarkAsRead, image: UIImage(systemName: "envelope.open"), handler: { _ in
                let selectedCellViewModels = self.selectedCellViewModels()
                self.viewModel.markAsReadOrUnread(viewModels: selectedCellViewModels, shouldMarkRead: true)
                self.isEditing = false
            }),
            UIAction(title: CommonStrings.notificationsCenterMarkAsUnread, image: UIImage(systemName: "envelope"), handler: { _ in
                let selectedCellViewModels = self.selectedCellViewModels()
                self.viewModel.markAsReadOrUnread(viewModels: selectedCellViewModels, shouldMarkRead: false)
                self.isEditing = false
            })
        ])
        let markButton: UIBarButtonItem
        let markText = WMFLocalizedString("notifications-center-mark", value: "Mark", comment: "Button text in Notifications Center. Presents menu of options to mark selected notifications as read or unread.")
        if #available(iOS 14.0, *) {
            markButton = UIBarButtonItem(title: markText, image: nil, primaryAction: nil, menu: optionsMenu)
        } else {
            markButton = UIBarButtonItem(title: markText, style: .plain, target: self, action: #selector(didTapMarkButtonIOS13(_:)))
        }
        return markButton
    }
    
    @objc func didTapMarkButtonIOS13(_ sender: UIBarButtonItem) {
        
        var numberSelected: Int?
        switch viewModel.state {
        case .data(_, let dataState):
            switch dataState {
            case .editing(let editingState):
                switch editingState {
                case .oneOrMoreSelected(let num):
                    numberSelected = num
                default:
                    assertionFailure("Unexpected view model state, should be in oneOrMoreSelected editing state.")
                    return
                }
            default:
                assertionFailure("Unexpected view model state, should be in oneOrMoreSelected editing state.")
                return
            }
        default:
            assertionFailure("Unexpected view model state, should be in oneOrMoreSelected editing state.")
            return
        }
        
        guard let numberSelected = numberSelected else {
            return
        }
        
        let titleFormat = WMFLocalizedString("notifications-center-num-selected-messages-format", value:"{{PLURAL:%1$d|%1$d message|%1$d messages}}", comment:"Title for options menu when choosing \"Mark\" toolbar button in notifications center editing mode - %1$d is replaced with the number of selected notifications.")
        let title = String.localizedStringWithFormat(titleFormat, numberSelected)

        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        let action1 = UIAlertAction(title: CommonStrings.notificationsCenterMarkAsRead, style: .default) { _ in
            let selectedCellViewModels = self.selectedCellViewModels()
            self.viewModel.markAsReadOrUnread(viewModels: selectedCellViewModels, shouldMarkRead: true)
            self.isEditing = false
        }
        
        let action2 = UIAlertAction(title: CommonStrings.notificationsCenterMarkAsUnread, style: .default) { _ in
            let selectedCellViewModels = self.selectedCellViewModels()
            self.viewModel.markAsReadOrUnread(viewModels: selectedCellViewModels, shouldMarkRead: false)
            self.isEditing = false
        }
        
        let cancelAction = UIAlertAction(title: CommonStrings.cancelActionTitle, style: .cancel, handler: nil)
        alertController.addAction(action1)
        alertController.addAction(action2)
        alertController.addAction(cancelAction)
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = sender
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func didTapMarkAllAsReadButton(_ sender: UIBarButtonItem) {
        
        var numberOfUnreadNotifications: Int?
        switch viewModel.state {
        case .data(_, let dataState):
            switch dataState {
            case .editing(let editingState):
                switch editingState {
                case .noneSelected(let num):
                    numberOfUnreadNotifications = num
                default:
                    assertionFailure("Unexpected view model state, should be in oneOrMoreSelected editing state.")
                    return
                }
            default:
                assertionFailure("Unexpected view model state, should be in oneOrMoreSelected editing state.")
                return
            }
        default:
            assertionFailure("Unexpected view model state, should be in oneOrMoreSelected editing state.")
            return
        }
        
        let titleText: String
        if let numberOfUnreadNotifications = numberOfUnreadNotifications {
            let titleFormat = WMFLocalizedString("notifications-center-mark-all-as-read-confirmation-format", value:"Are you sure that you want to mark all {{PLURAL:%1$d|%1$d message|%1$d messages}} of your notifications as read? Your notifications will be marked as read on all of your devices.", comment:"Title format for confirmation alert when choosing \"Mark all as read\" toolbar button in notifications center editing mode - %1$d is replaced with the number of unread notifications on the server.")
            titleText = String.localizedStringWithFormat(titleFormat, numberOfUnreadNotifications)
        } else {
            titleText = WMFLocalizedString("notifications-center-mark-all-as-read-missing-number", value:"Are you sure that you want to mark all of your notifications as read? Your notifications will be marked as read on all of your devices.", comment:"Title for confirmation alert when choosing \"Mark all as read\" toolbar button in notifications center editing mode, when there was an issue with pulling the count of unread notifications on the server.")
        }
        
        let alertController = UIAlertController(title: titleText, message: nil, preferredStyle: .actionSheet)
        let action = UIAlertAction(title: CommonStrings.notificationsCenterMarkAsRead, style: .destructive) { _ in
            self.viewModel.markAllAsRead()
            self.isEditing = false
        }
        let cancelAction = UIAlertAction(title: CommonStrings.cancelActionTitle, style: .cancel, handler: nil)
        alertController.addAction(action)
        alertController.addAction(cancelAction)
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = sender
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc func didTapFilterButton() {
        presentFiltersViewController()
    }
    
    @objc func didTapInboxButton() {
        presentInboxViewController()
    }
    
    func presentFiltersViewController() {
        
        let filtersViewModel = NotificationsCenterFiltersViewModel(remoteNotificationsController: viewModel.remoteNotificationsController, theme: theme)
        
        guard let filtersViewModel = filtersViewModel else {
            return
        }
        
        let filterView = NotificationsCenterFilterView(viewModel: filtersViewModel) { [weak self] in
                
                self?.dismiss(animated: true)
        }
        
        let hostingVC = UIHostingController(rootView: filterView)
        
        let nc = DisappearingCallbackNavigationController(rootViewController: hostingVC, theme: self.theme)
        nc.willDisappearCallback = { [weak self] in
            guard let self = self else {
                return
            }
            
            self.viewModel.resetAndRefreshData()
            self.viewModel.filtersToolbarViewModelNeedsReload()
            self.scrollToTop()
        }
        
        nc.modalPresentationStyle = .pageSheet
        self.present(nc, animated: true, completion: nil)
    }
    
    func presentInboxViewController() {
        
        viewModel.remoteNotificationsController.allInboxProjects(languageLinkController: viewModel.languageLinkController) { [weak self] projects in
            
            guard let self = self else {
                return
            }
            
            guard let inboxViewModel = NotificationsCenterInboxViewModel(remoteNotificationsController: self.viewModel.remoteNotificationsController, allInboxProjects: Set(projects), theme: self.theme) else {
                return
            }
            
            let inboxView = NotificationsCenterInboxView(viewModel: inboxViewModel) { [weak self] in
            
                self?.dismiss(animated: true)
            }

            let hostingVC = UIHostingController(rootView: inboxView)
            
            let nc = DisappearingCallbackNavigationController(rootViewController: hostingVC, theme: self.theme)
            nc.willDisappearCallback = { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.viewModel.resetAndRefreshData()
                self.viewModel.filtersToolbarViewModelNeedsReload()
                self.scrollToTop()
            }
            
            nc.modalPresentationStyle = .pageSheet
            self.present(nc, animated: true, completion: nil)
            
        }
    }
    
    func filterButtonImageForFiltersEnabled(_ filtersEnabled: Bool) -> UIImage? {
        if #available(iOS 15.0, *) {
            return UIImage(systemName: filterButtonNameForFiltersEnabled(filtersEnabled))
        } else {
            return UIImage(named: filterButtonNameForFiltersEnabled(filtersEnabled))
        }
    }
    
    func inboxButtonImageForFiltersEnabled(_ filtersEnabled: Bool) -> UIImage? {
            return UIImage(systemName: inboxButtonNameForFiltersEnabled(filtersEnabled))
    }
    
    func filterButtonNameForFiltersEnabled(_ filtersEnabled: Bool) -> String {
        return filtersEnabled ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }
    
    func inboxButtonNameForFiltersEnabled(_ filtersEnabled: Bool) -> String {
        return filtersEnabled ? "tray.fill" : "tray.2"
    }
    
    func filterEmptyStateSubtitleAttributedStringForFilterViewModel(_ filterViewModel: NotificationsCenterViewModel.FiltersToolbarViewModel) -> NSAttributedString? {
            let filtersLinkFormat = WMFLocalizedString("notifications-center-empty-state-num-filters", value:"{{PLURAL:%1$d|%1$d filter|%1$d filters}}", comment:"Portion of empty state subtitle showing number of filters the user has set in notifications center - %1$d is replaced with the number filters.")
            let filtersSubtitleFormat = WMFLocalizedString("notifications-center-empty-state-filters-subtitle", value:"Modify %1$@ to see more messages", comment:"Format of empty state subtitle when the user has filters on - %1$@ is replaced with a string representing the number of filters the user has set.")
            let filtersLink = String.localizedStringWithFormat(filtersLinkFormat, filterViewModel.countOfTypeFilters)
            let filtersSubtitle = String.localizedStringWithFormat(filtersSubtitleFormat, filtersLink)

            let rangeOfFiltersLink = (filtersSubtitle as NSString).range(of: filtersLink)

            let font = UIFont.wmf_font(.subheadline, compatibleWithTraitCollection: traitCollection)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.foregroundColor: theme.colors.secondaryText
                ]
            let linkAttributes = [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.foregroundColor: theme.colors.link
                ]
        
            let attributedString = NSMutableAttributedString(string: filtersSubtitle)
            attributedString.setAttributes(attributes, range: NSRange(location: 0, length: filtersSubtitle.count) )
            if rangeOfFiltersLink.location != NSNotFound {
                attributedString.setAttributes(linkAttributes, range: rangeOfFiltersLink)
            }

            return attributedString.copy() as? NSAttributedString
    }
    
    @objc func tappedEmptyStateSubheader() {
        presentFiltersViewController()
    }
}

// MARK: - NotificationCenterViewModelDelegate

extension NotificationsCenterViewController: NotificationCenterViewModelDelegate {
    
    func stateDidChange(_ newState: NotificationsCenterViewModel.State) {
        updateToolbar(for: newState)
        switch newState {
        case .empty(let emptyState):
            switch emptyState {
            case .loading:
                configureEmptyState(isEmpty: true, subheaderText: NotificationsCenterView.EmptyOverlayStrings.checkingForNotifications)
            case .noData, .inboxFilters:
                configureEmptyState(isEmpty: true)
            case .filters:
                if viewModel.filtersToolbarViewModel.countOfTypeFilters == 0 {
                    configureEmptyState(isEmpty: true)
                } else {
                    configureEmptyState(isEmpty: true, subheaderAttributedString: filterEmptyStateSubtitleAttributedStringForFilterViewModel(viewModel.filtersToolbarViewModel))
                }
            case .initial:
                configureEmptyState(isEmpty: false)
            case .subscriptions:
                //TODO: subscriptions text
                configureEmptyState(isEmpty: true)
            }
        case .data(let cellViewModels, let dataState):
            configureEmptyState(isEmpty: false)
            applySnapshot(cellViewModels: cellViewModels, animatingDifferences: true)
            reconfigureCells()
            
            switch dataState {
            case .nonEditing:
                deselectCells()
            case .editing(let editingState):
                switch editingState {
                case .noneSelected:
                    deselectCells()
                case .oneOrMoreSelected:
                    break
                }
            }
        }
    }
    
    var numCellsSelected: Int {
        return notificationsView.collectionView.indexPathsForSelectedItems?.count ?? 0
    }
    
    func filtersToolbarViewModelDidChange(_ newViewModel: NotificationsCenterViewModel.FiltersToolbarViewModel) {
        filterButton.image = filterButtonImageForFiltersEnabled(newViewModel.areFiltersEnabled)
        inboxButton.image = inboxButtonImageForFiltersEnabled(newViewModel.areInboxFiltersEnabled)
    }
}

extension NotificationsCenterViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        guard let dataSource = dataSource else {
            return
        }
        
        let count = dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
        let isLast = indexPath.row == count - 1
        if isLast {
            viewModel.fetchNextPage()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        if viewModel.state.isEditing {
            return true
        }
        
        return false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let cellViewModel = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }
        
        if cellSwipeData.activeCell(in: collectionView) != nil {
            closeActiveSwipePanelIfNecessary()
            return
        }
        
        let callbackForReload = viewModel.state.isEditing
        viewModel.updateCellSelectionState(cellViewModel: cellViewModel, isSelected: true, callbackForReload: callbackForReload)

        if !viewModel.state.isEditing {

            if let primaryURL = cellViewModel.primaryURL(for: viewModel.configuration) {
                navigate(to: primaryURL)
                if !cellViewModel.isRead {
                    viewModel.markAsReadOrUnread(viewModels: [cellViewModel], shouldMarkRead: true)
                }
            }
            
            viewModel.updateCellSelectionState(cellViewModel: cellViewModel, isSelected: false)
            notificationsView.collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        guard let cellViewModel = dataSource?.itemIdentifier(for: indexPath) else {
            return
        }
        
        let callbackForReload = viewModel.state.isEditing
        viewModel.updateCellSelectionState(cellViewModel: cellViewModel, isSelected: false, callbackForReload: callbackForReload)
    }
}

// MARK: - Cell Swipe Actions

@objc extension NotificationsCenterViewController: UIGestureRecognizerDelegate {

    /// Only allow cell pan gesture if user's horizontal cell panning behavior seems intentional
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == cellPanGestureRecognizer {
            let panVelocity = cellPanGestureRecognizer.velocity(in: notificationsView.collectionView)
            if abs(panVelocity.x) > abs(panVelocity.y) {
                return true
            }
        }

        return false
    }

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        super.scrollViewWillBeginDragging(scrollView)
        closeActiveSwipePanelIfNecessary()
    }

    func closeActiveSwipePanelIfNecessary() {
        if let activeCell = cellSwipeData.activeCell(in: notificationsView.collectionView){
            animateSwipePanel(open: false, for: activeCell)
            cellSwipeData.resetActiveData()
            deselectCells()
        }
    }

    fileprivate func animateSwipePanel(open: Bool, for cell: NotificationsCenterCell) {
       UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
           if open {
               cell.foregroundContentContainer.transform = CGAffineTransform.identity.translatedBy(x: -cell.swipeActionButtonStack.frame.size.width, y: 0)
           } else {
               cell.foregroundContentContainer.transform = CGAffineTransform.identity
           }
       }, completion: nil)
    }

    @objc fileprivate func userDidPanCell(_ gestureRecognizer: UIPanGestureRecognizer) {
        // TODO let isRTL = UIApplication.shared.wmf_isRTL
        let triggerVelocity: CGFloat = 400
        let swipeEdgeBuffer = NotificationsCenterCell.swipeEdgeBuffer
        let touchPosition = gestureRecognizer.location(in: notificationsView.collectionView)
        let translationX = gestureRecognizer.translation(in: notificationsView.collectionView).x
        let velocityX = gestureRecognizer.velocity(in: notificationsView.collectionView).x

        switch gestureRecognizer.state {
        case .began:
            guard let touchCellIndexPath = notificationsView.collectionView.indexPathForItem(at: touchPosition), let cell = notificationsView.collectionView.cellForItem(at: touchCellIndexPath) as? NotificationsCenterCell else {
                gestureRecognizer.state = .ended
                break
            }

            // If the new touch is on a new cell, and a current cell is already open, close it first
            if let currentlyActiveIndexPath = cellSwipeData.activelyPannedCellIndexPath, currentlyActiveIndexPath != touchCellIndexPath, let cell = notificationsView.collectionView.cellForItem(at: currentlyActiveIndexPath) as? NotificationsCenterCell {
                animateSwipePanel(open: false, for: cell)
            }

            if cell.foregroundContentContainer.transform.isIdentity {
                cellSwipeData.activelyPannedCellTranslationX = nil
                if velocityX > 0 {
                    gestureRecognizer.state = .ended
                    break
                }
            } else {
                cellSwipeData.activelyPannedCellTranslationX = cell.foregroundContentContainer.transform.tx
            }

            cellSwipeData.activelyPannedCellIndexPath = touchCellIndexPath
        case .changed:
            guard let cell = cellSwipeData.activeCell(in: notificationsView.collectionView) else {
                break
            }

            let swipeStackWidth = cell.swipeActionButtonStack.frame.size.width
            var totalTranslationX = translationX + (cellSwipeData.activelyPannedCellTranslationX ?? 0)

            let maximumTranslationX = swipeStackWidth + swipeEdgeBuffer

            // The user is trying to pan too far left
            if totalTranslationX < -maximumTranslationX {
                totalTranslationX = -maximumTranslationX - log(abs(translationX))
            }

            // Extends too far right
            if totalTranslationX > swipeEdgeBuffer {
                totalTranslationX = swipeEdgeBuffer + log(abs(translationX))
            }

            cell.foregroundContentContainer.transform = CGAffineTransform(translationX: totalTranslationX, y: 0)
        case .ended:
            guard let cell = cellSwipeData.activeCell(in: notificationsView.collectionView) else {
                break
            }

            var shouldOpenSwipePanel: Bool
            let currentCellTranslationX = cell.foregroundContentContainer.transform.tx

            if currentCellTranslationX > 0 {
                shouldOpenSwipePanel = false
            } else {
                if velocityX < -triggerVelocity {
                    shouldOpenSwipePanel = true
                } else {
                    shouldOpenSwipePanel = abs(currentCellTranslationX) > (0.5 * cell.swipeActionButtonStack.frame.size.width)
                }
            }

            if velocityX > triggerVelocity {
                shouldOpenSwipePanel = false
            }

            if !shouldOpenSwipePanel {
                cellSwipeData.resetActiveData()
            }

            animateSwipePanel(open: shouldOpenSwipePanel, for: cell)
        default:
            break
        }
    }

}

//MARK: NotificationCenterCellDelegate

extension NotificationsCenterViewController: NotificationsCenterCellDelegate {

    func userDidTapSecondaryActionForViewModel(_ cellViewModel: NotificationsCenterCellViewModel) {
        guard cellSwipeData.activeCell(in: notificationsView.collectionView) == nil else {
            closeActiveSwipePanelIfNecessary()
            return
        }

        guard let url = cellViewModel.secondaryURL(for: viewModel.configuration) else {
            return
        }

        navigate(to: url)
        if !cellViewModel.isRead {
            viewModel.markAsReadOrUnread(viewModels: [cellViewModel], shouldMarkRead: true)
        }
    }

    func userDidTapMoreActionForCell(_ cell: NotificationsCenterCell) {
        guard let cellViewModel = cell.viewModel else {
            return
        }

        closeActiveSwipePanelIfNecessary()

        let sheetActions = cellViewModel.sheetActions(for: viewModel.configuration)
        guard !sheetActions.isEmpty else {
            return
        }

        let alertController = UIAlertController(title: cellViewModel.headerText, message: cellViewModel.bodyText ?? cellViewModel.subheaderText, preferredStyle: .actionSheet)

        sheetActions.forEach { action in

            let alertAction: UIAlertAction
            switch action {
            case .markAsReadOrUnread(let data):
                alertAction = UIAlertAction(title: data.text, style: .default, handler: { alertAction in
                    let shouldMarkRead = cellViewModel.isRead ? false : true
                    self.viewModel.markAsReadOrUnread(viewModels: [cellViewModel], shouldMarkRead: shouldMarkRead)
                })
            case .notificationSubscriptionSettings(let data):
                alertAction = UIAlertAction(title: data.text, style: .default, handler: { alertAction in
                    let userActivity = NSUserActivity.wmf_notificationSettings()
                    NSUserActivity.wmf_navigate(to: userActivity)
                    if !cellViewModel.isRead {
                        self.viewModel.markAsReadOrUnread(viewModels: [cellViewModel], shouldMarkRead: true)
                    }
                })
            case .custom(let data):
                alertAction = UIAlertAction(title: data.text, style: .default, handler: { alertAction in
                    let url = data.url
                    self.navigate(to: url)
                    if !cellViewModel.isRead {
                        self.viewModel.markAsReadOrUnread(viewModels: [cellViewModel], shouldMarkRead: true)
                    }
                })
            }

            alertController.addAction(alertAction)
        }

        let cancelAction = UIAlertAction(title: CommonStrings.cancelActionTitle, style: .cancel)
        alertController.addAction(cancelAction)

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = cell
            popoverController.sourceRect = CGRect(x: cell.bounds.midX, y: cell.bounds.midY, width: 0, height: 0)
        }

        present(alertController, animated: true, completion: nil)
    }

    func userDidTapMarkAsReadUnreadActionForCell(_ cell: NotificationsCenterCell) {
        guard let cellViewModel = cell.viewModel else {
            return
        }
        
        closeActiveSwipePanelIfNecessary()
        viewModel.markAsReadOrUnread(viewModels: [cellViewModel], shouldMarkRead: !cellViewModel.isRead)
    }

}
