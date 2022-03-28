
import SwiftUI
import WMF

struct NotificationsCenterFilterItemView: View {
    @Environment (\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var itemViewModel: NotificationsCenterFiltersViewModel.ItemViewModel
    let theme: Theme

    var body: some View {
        
        Group {
            
            switch itemViewModel.selectionType {
            case .checkmark:
                
                Button(action: {
                    itemViewModel.toggleSelectionForCheckmarkType()
                }) {
                    HStack {
                        Text(itemViewModel.title)
                            .foregroundColor(Color(theme.colors.primaryText))
                        Spacer()
                        if (itemViewModel.isSelected) {
                            Image(systemName: "checkmark")
                                .font(Font.body.weight(.semibold))
                                .foregroundColor(Color(theme.colors.link))
                        }
                    }
                }
            case .toggle(let remoteNotificationType):
                
                HStack {

                    let iconColor = theme.colors.paperBackground
                    let iconBackgroundColor = remoteNotificationType.imageBackgroundColorWithTheme(theme)
                    if let iconName = remoteNotificationType.imageName {
                        NotificationsCenterIconImage(iconName: iconName, iconColor: Color(iconColor), iconBackgroundColor: Color(iconBackgroundColor), padding: 0)
                    }
                    
                    if #available(iOS 14.0, *) {
                        Toggle(itemViewModel.title, isOn: $itemViewModel.isSelected.didSet { (state) in
                            itemViewModel.toggleSelectionForToggleType()
                        })
                            .foregroundColor(Color(theme.colors.primaryText))
                            .toggleStyle(SwitchToggleStyle(tint: Color(theme.colors.accent)))
                    } else {
                        Toggle(itemViewModel.title, isOn: $itemViewModel.isSelected.didSet { (state) in
                            itemViewModel.toggleSelectionForToggleType()
                        })
                            .foregroundColor(Color(theme.colors.primaryText))
                    }
                }
            case .toggleAll:
                if #available(iOS 14.0, *) {
                    Toggle(itemViewModel.title, isOn: $itemViewModel.isSelected.didSet { (state) in
                        itemViewModel.toggleSelectionForAll()
                    })
                    .foregroundColor(Color(theme.colors.primaryText))
                    .toggleStyle(SwitchToggleStyle(tint: Color(theme.colors.accent)))
                } else {
                    Toggle(itemViewModel.title, isOn: $itemViewModel.isSelected.didSet { (state) in
                        itemViewModel.toggleSelectionForAll()
                    })
                    .foregroundColor(Color(theme.colors.primaryText))
                }
            }
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 0)
        .listRowBackground(Color(theme.colors.paperBackground).edgesIgnoringSafeArea([.all]))
    }
}

extension Binding {
    func didSet(execute: @escaping (Value) -> Void) -> Binding {
        return Binding(
            get: { self.wrappedValue },
            set: {
                self.wrappedValue = $0
                execute($0)
            }
        )
    }
}

struct NotificationsCenterFilterView: View {

    let viewModel: NotificationsCenterFiltersViewModel
    let doneAction: () -> Void
    
    var body: some View {
            List {
                ForEach(viewModel.sections) { section in
                    
                    if let title = section.title {
                        let header = Text(title).foregroundColor(Color(viewModel.theme.colors.secondaryText))
                        if let footer = section.footer {
                            let footer = Text(footer)
                                .foregroundColor(Color(viewModel.theme.colors.secondaryText))
                            Section(header: header, footer: footer) {
                                ForEach(section.items) { item in
                                    NotificationsCenterFilterItemView(itemViewModel: item, theme: viewModel.theme)
                                }
                            }
                        } else {
                            Section(header: header) {
                                ForEach(section.items) { item in
                                    NotificationsCenterFilterItemView(itemViewModel: item, theme: viewModel.theme)
                                }
                            }
                        }
                    } else {
                        Section() {
                            ForEach(section.items) { item in
                                NotificationsCenterFilterItemView(itemViewModel: item, theme: viewModel.theme)
                            }
                        }
                    }
                }
            }
            .listStyle(GroupedListStyle())
            .navigationBarItems(
                trailing:
                    Button(action: {
                        doneAction()
                    }) {
                        Text(CommonStrings.doneTitle)
                            .fontWeight(Font.Weight.semibold)
                            .foregroundColor(Color(viewModel.theme.colors.primaryText))
                        }
            )
            .background(Color(viewModel.theme.colors.baseBackground).edgesIgnoringSafeArea(.all))
            .navigationBarTitle(Text(WMFLocalizedString("notifications-center-filters-title", value: "Filters", comment: "Navigation bar title text for the filters view presented from notifications center. Allows for filtering by read status and notification type.")), displayMode: .inline)
            .onAppear(perform: {
                    UITableView.appearance().backgroundColor = UIColor.clear
            })
            .onDisappear(perform: {
                
                UITableView.appearance().backgroundColor = UIColor.systemGroupedBackground
            })
    }
}
