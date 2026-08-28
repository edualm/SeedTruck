//
//  TorrentHandlerView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct TorrentHandlerView: View {
    
    typealias DismissHandler = () -> Void
    
    @EnvironmentObject private var serverRepository: ServerRepository

    var serverConnections: [Server] { serverRepository.servers }
    var server: Server? { serverID.flatMap(serverRepository.server(id:)) }
    var selectedServers: [Server] {
        get { selectedServerIDs.compactMap(serverRepository.server(id:)) }
        nonmutating set { selectedServerIDs = newValue.map(\.id) }
    }
    
    @State var errorMessage: String? = nil
    @State var processing: Bool = false
    @State var selectedServerIDs: [UUID] = []
    @State var selectedLabels: [String] = []
    @State var serverLabels: [String] = []
    @State var labelLoadGeneration = 0
    @State var loadedConnectionDetails: [ConnectionDetails] = []
    
    let torrent: LocalTorrent
    let serverID: UUID?
    let dismissHandler: DismissHandler

    init(torrent: LocalTorrent, server: Server?, dismissHandler: @escaping DismissHandler) {
        self.torrent = torrent
        self.serverID = server?.id
        self.dismissHandler = dismissHandler
    }

    @ViewBuilder
    private var destinationSection: some View {
        if let server {
            HStack(spacing: 12) {
                Label(server.name, systemImage: "server.rack")
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Destination, \(server.name)")
        } else if !serverConnections.isEmpty {
            ForEach(0 ..< serverConnections.count, id: \.self) { index in
                let server = serverConnections[index]
                Button {
                    if selectedServers.contains(server) {
                        selectedServers.removeAll { $0 == server }
                    } else {
                        selectedServers.append(server)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Label(server.name, systemImage: "server.rack")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(
                            systemName: selectedServers.contains(server)
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .foregroundStyle(selectedServers.contains(server) ? Color.accentColor : Color.secondary)
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityAddTraits(selectedServers.contains(server) ? .isSelected : [])
                .accessibilityIdentifier("torrent-server-\(index)")
            }
        } else {
            NoServersWarningView()
                .padding(.vertical, 4)
        }
    }

    private var actionBar: some View {
        TorrentImportActionBar(
            cancelAction: dismissHandler,
            primaryAction: startDownload,
            cancelDisabled: processing,
            primaryDisabled: selectedServers.isEmpty || processing,
            cancelAccessibilityIdentifier: "torrent-cancel",
            primaryAccessibilityIdentifier: "torrent-start-download"
        ) {
            EmptyView()
        } primaryLabel: {
            HStack(spacing: 8) {
                if processing {
                    ProgressView()
                        .tint(.white)
                        .accessibilityHidden(true)
                    Text("Adding Torrent...")
                } else {
                    Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                }
            }
            .fontWeight(.semibold)
        }
    }
    
    var normalBody: some View {
        Form {
            Section {
                TorrentSummaryView(torrent: torrent)
                    .padding(.vertical, 6)
            }
            
            Section {
                destinationSection
            } header: {
                Text("Download To")
            } footer: {
                if server == nil && !serverConnections.isEmpty {
                    Text("Choose one or more torrent servers.")
                }
            }
            
            if !serverLabels.isEmpty {
                Section {
                    LabelPickerView(selectedLabels: $selectedLabels, labels: serverLabels)
                } header: {
                    Text("Labels")
                } footer: {
                    Text("Optional labels shared by the selected servers.")
                }
            }
        }
        .disabled(processing)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .alert(isPresented: showingError) {
            Alert(
                title: Text("Unable to Add Torrent"),
                message: Text(errorMessage ?? "The torrent could not be added."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var body: some View {
        sharedBody
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(processing)
    }
    
    func loadLabelsFromServer() {
        labelLoadGeneration += 1
        let generation = labelLoadGeneration
        let servers = server.map { [$0] } ?? selectedServers
        guard !servers.isEmpty else {
            serverLabels = []
            return
        }

        let providers = servers.compactMap { $0.connection as? TorrentTagProviding }
        guard providers.count == servers.count else {
            serverLabels = []
            return
        }

        Task {
            let tagSets: [Set<String>] = await withTaskGroup(of: Set<String>?.self) { group in
                for provider in providers {
                    group.addTask {
                        try? await Set(provider.availableTags())
                    }
                }

                var results: [Set<String>] = []
                for await result in group {
                    guard let result else {
                        return [Set<String>]()
                    }
                    results.append(result)
                }
                return results
            }
            guard let first = tagSets.first else {
                if generation == labelLoadGeneration {
                    serverLabels = []
                }
                return
            }
            guard generation == labelLoadGeneration else {
                return
            }
            serverLabels = tagSets.dropFirst().reduce(first, { $0.intersection($1) }).sorted()
            selectedLabels.removeAll { !serverLabels.contains($0) }
        }
    }
}

struct TorrentHandlerNavigationView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    let torrent: LocalTorrent
    let server: Server?
    
    func dismissHandler() {
        presentation.wrappedValue.dismiss()
    }
    
    var body: some View {
        NavigationStack {
            TorrentHandlerView(torrent: torrent,
                               server: server,
                               dismissHandler: dismissHandler)
        }
    }
}

struct TorrentHandlerNavigationView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            TorrentHandlerNavigationView(torrent: PreviewMockData.localTorrentFile,
                                         server: nil)
                .previewDisplayName("Torrent File")

            TorrentHandlerNavigationView(torrent: PreviewMockData.localTorrentMagnet,
                                         server: nil)
                .previewDisplayName("Magnet Link")
        }
        .environmentObject(PreviewMockData.serverRepository)
    }
}
