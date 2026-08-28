//
//  TorrentsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentsView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private struct AlertIdentifier: Identifiable {

        let id = UUID()
        let message: String
    }
    
    private enum PresentedSheet {
        
        case addMagnet
        case addTorrent(LocalTorrent)
    }
    
    @State var pickerAdapter: DocumentPickerAdapter?
    
    private var addMenuItems: [MenuItem] {
        [
            .init(name: "Magnet Link", systemImage: "link") {
                self.presentedSheet = .addMagnet
            },
            .init(name: "Torrent File", systemImage: "doc") {
                let adapter = DocumentPickerAdapter(
                    torrentPickerWithOnPick: { url in
                        do {
                            self.presentedSheet = .addTorrent(try LocalTorrent(validating: url))
                        } catch {
                            self.showingAlert = .init(message: error.localizedDescription)
                        }
                    },
                    onDismiss: {}
                )
                self.pickerAdapter = adapter

                UIApplication
                    .shared
                    .connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .last?
                    .rootViewController?
                    .present(adapter.picker, animated: true)
            }
        ]
    }
    
    @EnvironmentObject private var serverRepository: ServerRepository

    var serverConnections: [Server] { serverRepository.servers }
    
    @State private var showingAlert: AlertIdentifier?
    @State private var presentedSheet: PresentedSheet?
    
    @State var filter: Filter?
    @State private var selectedServerID: UUID?
    @State var selectedTorrentId: String?
    @AppStorage(Constants.StorageKeys.torrentSort) var sort: TorrentSort = .name
    @AppStorage(Constants.StorageKeys.torrentSortDirection) var sortDirection: TorrentSortDirection = .ascending
    
    @State var filterQuery: String = ""
    @State private var torrents: [RemoteTorrent] = []
    @StateObject private var actionController = TorrentActionController()
    @StateObject private var listState = TorrentListState()

    var selectedServer: Server? {
        get {
            serverConnections.first { $0.id == selectedServerID }
        }
        nonmutating set {
            selectedServerID = newValue?.id
        }
    }

    private var selectedServerBinding: Binding<Server?> {
        Binding(
            get: { selectedServer },
            set: { selectedServerID = $0?.id }
        )
    }

    var leadingNavigationBarItems: some View {
        Group {
            if serverConnections.count > 1 {
                Menu {
                    ForEach(serverConnections, id: \.self) { server in
                        Button {
                            selectedServer = server
                        } label: {
                            Text(server.name)
                            Image(systemName: "server.rack")
                            if selectedServer?.id == server.id {
                                Image(systemName: "checkmark")
                            }
                        }
                        .accessibilityAddTraits(
                            selectedServer?.id == server.id ? .isSelected : []
                        )
                    }
                } label: {
                    Image(systemName: "text.justify")
                }
                .accessibilityLabel("Choose Server")
                .accessibilityValue(selectedServer?.name ?? "No server selected")
                .accessibilityHint("Shows available torrent clients")
            } else {
                EmptyView()
            }
        }
    }
    
    var trailingNavigationBarItems: some View {
        Group {
            if serverConnections.count > 0 {
                HStack(spacing: 16) {
                    Menu {
                        Button {
                            filter = nil
                        } label: {
                            Label("Show All", systemImage: "circle.fill")
                            if filter == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                        .accessibilityAddTraits(filter == nil ? .isSelected : [])
                        Divider()
                        
                        ForEach(Filter.allCases) { option in
                            Button {
                                filter = option
                            } label: {
                                Label(option.label, systemImage: option.systemImage)
                                if filter == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .accessibilityAddTraits(filter == option ? .isSelected : [])
                        }
                    } label: {
                        Image(systemName: filter != nil ? "tag.fill" : "tag")
                    }
                    .accessibilityLabel(filter.map { "Filter: \($0.label)" } ?? "Filter: Show All")

                    Menu {
                        Picker("Sort By", selection: $sort) {
                            ForEach(TorrentSort.allCases) { option in
                                Label(option.label, systemImage: option.systemImage)
                                    .tag(option)
                            }
                        }
                        Divider()
                        Picker("Order", selection: $sortDirection) {
                            ForEach(TorrentSortDirection.allCases) { direction in
                                Label(direction.label, systemImage: direction.systemImage)
                                    .tag(direction)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .accessibilityLabel("Sort by \(sort.label), \(sortDirection.label)")
                    
                    Menu {
                        ForEach(addMenuItems, id: \.self) { item in
                            Button {
                                item.action()
                            } label: {
                                Text(item.name)
                                Image(systemName: item.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                    .accessibilityLabel("Add Torrent")
                    .accessibilityHint("Add a magnet link or torrent file")
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var body: some View {
        let isPresentingModal = Binding<Bool>(
            get: { presentedSheet != nil },
            set: { _ in presentedSheet = nil }
        )
        
        return navigationContent
        .onAppear(perform: onAppear)
        .onChange(of: serverConnections.map(\.id)) { _, serverIDs in
            guard let selectedServerID = selectedServer?.id,
                  serverIDs.contains(selectedServerID) else {
                selectedServer = serverConnections.first

                return
            }
        }
        .alert(item: $showingAlert) {
            Alert(
                title: Text("Unable to Add Torrent"),
                message: Text($0.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: isPresentingModal) {
            switch presentedSheet {
            case .addMagnet:
                AddMagnetView(server: selectedServerBinding)
            case .addTorrent(let torrent):
                TorrentHandlerNavigationView(torrent: torrent, server: selectedServer)
            case .none:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var navigationContent: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                torrentsContent
                    .navigationSplitViewColumnWidth(min: 300, ideal: 375)
            } detail: {
                selectedTorrentDetail
            }
        } else {
            NavigationStack(path: compactNavigationPath) {
                torrentsContent
                    .navigationDestination(for: String.self) { torrentID in
                        torrentDetail(for: torrentID)
                    }
            }
        }
    }

    private var compactNavigationPath: Binding<[String]> {
        Binding(
            get: { selectedTorrentId.map { [$0] } ?? [] },
            set: { selectedTorrentId = $0.last }
        )
    }

    private var torrentsContent: some View {
        TorrentsViewContent(
            selectedServer: selectedServerBinding,
            filter: $filter,
            filterQuery: $filterQuery,
            sort: $sort,
            sortDirection: $sortDirection,
            selectedTorrentId: $selectedTorrentId,
            actionController: actionController,
            listState: listState,
            usesListSelection: horizontalSizeClass == .regular,
            leadingNavigationBarItems: leadingNavigationBarItems,
            trailingNavigationBarItems: trailingNavigationBarItems,
            onSnapshotChange: { torrents in
                self.torrents = torrents
                if let selectedTorrentId,
                   !torrents.contains(where: { $0.id == selectedTorrentId }) {
                    self.selectedTorrentId = nil
                }
            }
        )
    }

    @ViewBuilder
    private var selectedTorrentDetail: some View {
        if let selectedTorrentId {
            torrentDetail(for: selectedTorrentId)
        } else {
            ContentUnavailableView(
                "Select a Torrent",
                systemImage: "sidebar.left",
                description: Text("Choose a torrent to view its details.")
            )
        }
    }

    @ViewBuilder
    private func torrentDetail(for torrentID: String) -> some View {
        if let server = selectedServer,
           let torrent = torrents.first(where: { $0.id == torrentID }) {
            let removedServerID = server.id
            let removedTorrentID = torrent.id

            TorrentDetailsViewWrapper(
                torrent: torrent,
                server: server,
                actionController: actionController,
                onRemovalCompleted: {
                    guard selectedServer?.id == removedServerID,
                          selectedTorrentId == removedTorrentID else {
                        return
                    }
                    selectedTorrentId = nil
                }
            )
                .id("\(server.id.uuidString):\(torrent.id)")
        } else {
            ContentUnavailableView(
                "Torrent Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("Refresh the list and try again.")
            )
        }
    }
}

private struct TorrentsViewContent<LeadingItems: View, TrailingItems: View>: View {
    
    @Binding var selectedServer: Server?
    @Binding var filter: Filter?
    @Binding var filterQuery: String
    @Binding var sort: TorrentSort
    @Binding var sortDirection: TorrentSortDirection
    @Binding var selectedTorrentId: String?
    let actionController: TorrentActionController
    let listState: TorrentListState
    let usesListSelection: Bool
    
    let leadingNavigationBarItems: LeadingItems
    let trailingNavigationBarItems: TrailingItems
    let onSnapshotChange: ([RemoteTorrent]) -> Void
    
    var body: some View {
        TorrentListView(
            server: $selectedServer,
            filter: $filter,
            filterQuery: $filterQuery,
            sort: $sort,
            sortDirection: $sortDirection,
            selectedTorrentId: $selectedTorrentId,
            actionController: actionController,
            listState: listState,
            usesListSelection: usesListSelection,
            onSnapshotChange: onSnapshotChange
        )
            .id("torrentListTop")
            .navigationTitle(selectedServer?.name ?? "Torrents")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: leadingNavigationBarItems,
                trailing: trailingNavigationBarItems
            )
            .searchable(
                text: $filterQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search torrents"
            )
            .searchPresentationToolbarBehaviorIfAvailable()
            .animation(.none, value: filterQuery)
    }
}

// Keep the navigation bar stable while search presentation changes during navigation.
@available(iOS, introduced: 17)
private struct SearchPresentationToolbarBehaviorModifier: ViewModifier {

    func body(content: Content) -> some View {
        if #available(iOS 17.1, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

private extension View {

    func searchPresentationToolbarBehaviorIfAvailable() -> some View {
        modifier(SearchPresentationToolbarBehaviorModifier())
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
