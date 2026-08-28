//
//  TorrentsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct TorrentsView: View {

    private enum PresentedSheet {

        case addMagnet
        case addTorrent(LocalTorrent, Server?)
    }

    @EnvironmentObject private var serverRepository: ServerRepository

    var serverConnections: [Server] { serverRepository.servers }
    
    @State private var selectedServerID: UUID?
    @State var filter: Filter?
    @State var selectedTorrentId: String?
    @AppStorage(Constants.StorageKeys.torrentSort) var sort: TorrentSort = .name
    @AppStorage(Constants.StorageKeys.torrentSortDirection) var sortDirection: TorrentSortDirection = .ascending
    @State private var torrents: [RemoteTorrent] = []
    @StateObject private var actionController = TorrentActionController()
    @State private var importErrorMessage: String?
    @State private var presentedSheet: PresentedSheet?
    @State private var showingTorrentFileImporter = false
    
    @State var filterQuery: String = ""

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

    private var importCommandActions: ImportCommandActions {
        ImportCommandActions(
            openTorrentFile: { showingTorrentFileImporter = true },
            openMagnetLink: { presentedSheet = .addMagnet }
        )
    }

    private var showingImportError: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }
    
    private func reloadData() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
        }
    }

    private func importTorrent(from url: URL, server: Server?) {
        do {
            presentedSheet = .addTorrent(try LocalTorrent(validating: url), server)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw TorrentImportError.unreadableFile
            }
            importTorrent(from: url, server: selectedServer)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private var torrentCommandActions: TorrentCommandActions? {
        guard let selectedTorrentId,
              let server = selectedServer,
              let torrent = torrents.first(where: { $0.id == selectedTorrentId }) else {
            return nil
        }

        let isPerformingAction = actionController.isPerformingAction(on: torrent, server: server)
        let canStart: Bool
        let canPause: Bool
        switch torrent.primaryAction {
        case .start:
            canStart = !isPerformingAction
            canPause = false
        case .stop:
            canStart = false
            canPause = !isPerformingAction
        case .remove, .none:
            canStart = false
            canPause = false
        }

        return TorrentCommandActions(
            canStart: canStart,
            canPause: canPause,
            start: { actionController.perform(.start, on: torrent, server: server) },
            pause: { actionController.perform(.stop, on: torrent, server: server) }
        )
    }
    
    var body: some View {
        let isPresentingSheet = Binding<Bool>(
            get: { presentedSheet != nil },
            set: { if !$0 { presentedSheet = nil } }
        )

        return NavigationSplitView {
            // Sidebar
            VStack {
                if serverConnections.count > 1 {
                    if let s = selectedServer {
                        Menu(s.name) {
                            ForEach(serverConnections, id: \.self) { server in
                                Button {
                                    selectedServer = server
                                } label: {
                                    Text(server.name)
                                    Image(systemName: "server.rack")
                                }
                            }
                        }.padding([.top, .leading, .trailing])
                    }
                    
                    Spacer()
                }
                
                HStack {
                    if serverConnections.count > 0 {
                        Menu {
                            Button {
                                filter = nil
                            } label: {
                                Label("Show All", systemImage: "circle.fill")
                                if filter == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                            
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
                            }
                        } label: {
                            if let filter {
                                Label(filter.label, systemImage: filter.systemImage)
                            } else {
                                Label("Show All", systemImage: "circle.fill")
                            }
                        }
                        .buttonStyle(.bordered)

                        Menu {
                            ForEach(TorrentSort.allCases) { option in
                                Button {
                                    sort = option
                                } label: {
                                    Label(option.label, systemImage: option.systemImage)
                                    if sort == option {
                                        Image(systemName: "checkmark")
                                    }
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
                            Label(sort.label, systemImage: sort.systemImage)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Sort by \(sort.label), \(sortDirection.label)")
                        
                        Spacer()
                        
                        Button {
                            reloadData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh Torrents")
                        .help("Refresh Torrents")
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                
                TorrentListView(
                    server: selectedServerBinding,
                    filter: $filter,
                    filterQuery: $filterQuery,
                    sort: $sort,
                    sortDirection: $sortDirection,
                    selectedTorrentId: $selectedTorrentId,
                    actionController: actionController,
                    onSnapshotChange: { torrents in
                        self.torrents = torrents
                        if let selectedTorrentId,
                           !torrents.contains(where: { $0.id == selectedTorrentId }) {
                            self.selectedTorrentId = nil
                        }
                    }
                )
            }
            .navigationTitle(selectedServer?.name ?? "Torrents")
            .searchable(text: $filterQuery, prompt: "Search torrents")
            .navigationSplitViewColumnWidth(min: 300, ideal: 375)
        } detail: {
            // Detail view
            if let torrentId = selectedTorrentId,
               let server = selectedServer,
               let torrent = torrents.first(where: { $0.id == torrentId }) {
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
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a torrent to view its details.")
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear(perform: onAppear)
        .onChange(of: serverConnections.map(\.id)) { _, serverIDs in
            guard let selectedServerID = selectedServer?.id,
                  serverIDs.contains(selectedServerID) else {
                selectedServer = serverConnections.first

                return
            }
        }
        .onOpenURL { importTorrent(from: $0, server: nil) }
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .fileImporter(
            isPresented: $showingTorrentFileImporter,
            allowedContentTypes: [UTI.torrent],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .sheet(isPresented: isPresentingSheet) {
            switch presentedSheet {
            case .addMagnet:
                AddMagnetView(server: selectedServerBinding)
            case .addTorrent(let torrent, let server):
                TorrentHandlerNavigationView(torrent: torrent, server: server)
            case .none:
                EmptyView()
            }
        }
        .alert("Unable to Add Torrent", isPresented: showingImportError) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "The torrent could not be imported.")
        }
        .focusedSceneValue(\.importCommandActions, importCommandActions)
        .focusedSceneValue(\.torrentCommandActions, torrentCommandActions)
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
