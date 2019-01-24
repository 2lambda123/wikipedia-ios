protocol SectionEditorMenuItemsDataSource: class {
    var availableMenuActions: [Selector] { get }
}

protocol SectionEditorMenuItemsDelegate: class {
    func sectionEditorWebViewDidTapSelectAll(_ sectionEditorWebView: SectionEditorWebView)
    func sectionEditorWebViewDidTapBoldface(_ sectionEditorWebView: SectionEditorWebView)
    func sectionEditorWebViewDidTapItalics(_ sectionEditorWebView: SectionEditorWebView)
    func sectionEditorWebViewDidTapCitation(_ sectionEditorWebView: SectionEditorWebView)
    func sectionEditorWebViewDidTapLink(_ sectionEditorWebView: SectionEditorWebView)
    func sectionEditorWebViewDidTapTemplate(_ sectionEditorWebView: SectionEditorWebView)
}

class SectionEditorMenuItemsController: NSObject, SectionEditorMenuItemsDataSource {
    let messagingController: SectionEditorWebViewMessagingController

    init(messagingController: SectionEditorWebViewMessagingController) {
        self.messagingController = messagingController
        super.init()
        setEditMenuItems()
    }

    // Keep original menu items
    // so that we can bring them back
    // when web view disappears
    var originalMenuItems: [UIMenuItem]?

    private func setEditMenuItems() {
        originalMenuItems = UIMenuController.shared.menuItems
        UIMenuController.shared.menuItems = menuItems
    }

    lazy var menuItems: [UIMenuItem] = {
        let addCitation = UIMenuItem(title: "Add Citation", action: #selector(SectionEditorWebView.toggleCitation(menuItem:)))
        let addLink = UIMenuItem(title: "Add Link", action: #selector(SectionEditorWebView.toggleLink(menuItem:)))
        let addTemplate = UIMenuItem(title: "｛ ｝", action: #selector(SectionEditorWebView.toggleTemplate(menuItem:)))
        let makeBold = UIMenuItem(title: "𝗕", action: #selector(SectionEditorWebView.toggleBoldface(menuItem:)))
        let makeItalic = UIMenuItem(title: "𝐼", action: #selector(SectionEditorWebView.toggleItalics(menuItem:)))
        return [addCitation, addLink, addTemplate, makeBold, makeItalic]
    }()

    lazy var availableMenuActions: [Selector] = {
        let actions = [
            #selector(SectionEditorWebView.cut(_:)),
            #selector(SectionEditorWebView.copy(_:)),
            #selector(SectionEditorWebView.paste(_:)),
            #selector(SectionEditorWebView.select(_:)),
            #selector(SectionEditorWebView.selectAll(_:)),
            #selector(SectionEditorWebView.toggleBoldface(menuItem:)),
            #selector(SectionEditorWebView.toggleItalics(menuItem:)),
            #selector(SectionEditorWebView.toggleCitation(menuItem:)),
            #selector(SectionEditorWebView.toggleLink(menuItem:)),
            #selector(SectionEditorWebView.toggleTemplate(menuItem:))
        ]
        return actions
    }()
}

extension SectionEditorMenuItemsController: SectionEditorMenuItemsDelegate {
    func sectionEditorWebViewDidTapSelectAll(_ sectionEditorWebView: SectionEditorWebView) {
        messagingController.selectAllText()
    }

    func sectionEditorWebViewDidTapBoldface(_ sectionEditorWebView: SectionEditorWebView) {
        messagingController.toggleBoldSelection()
    }

    func sectionEditorWebViewDidTapItalics(_ sectionEditorWebView: SectionEditorWebView) {
        messagingController.toggleItalicSelection()
    }

    func sectionEditorWebViewDidTapCitation(_ sectionEditorWebView: SectionEditorWebView) {
        messagingController.toggleReferenceSelection()
    }

    func sectionEditorWebViewDidTapLink(_ sectionEditorWebView: SectionEditorWebView) {
        messagingController.toggleAnchorSelection()
    }

    func sectionEditorWebViewDidTapTemplate(_ sectionEditorWebView: SectionEditorWebView) {
        messagingController.toggleTemplateSelection()
    }
}
