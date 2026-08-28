//
//  TorrentHandlerView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
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
    @State var serverLabels: [String] = []
    @State var selectedLabels: [String] = []
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
    
    var serverBindings: [Binding<Bool>] {
        serverConnections.map { server in
            Binding<Bool>(
                get: { selectedServers.contains(server) },
                set: { isSelected in
                    if isSelected {
                        guard !selectedServers.contains(server) else {
                            return
                        }
                        selectedServers.append(server)
                    } else {
                        selectedServers.removeAll { $0 == server }
                    }
                }
            )
        }
    }

    private var destinationStatus: String {
        switch selectedServers.count {
        case 0 where serverConnections.isEmpty && server == nil:
            return "Configure a server to continue"
        case 0:
            return "Select at least one server"
        case 1:
            return "Destination: \(selectedServers[0].name)"
        default:
            return "\(selectedServers.count) servers selected"
        }
    }

    @ViewBuilder
    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Download To",
                subtitle: server == nil ? "Choose one or more torrent servers." : "This torrent will be sent to the selected server."
            )

            if let server {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(server.name)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Destination, \(server.name)")
            } else if !serverConnections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0 ..< serverConnections.count, id: \.self) { index in
                        Toggle(isOn: serverBindings[index]) {
                            Label(serverConnections[index].name, systemImage: "server.rack")
                                .foregroundStyle(.primary)
                        }
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier("torrent-server-\(index)")
                    }
                }
            } else {
                NoServersWarningView()
            }
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Labels",
                subtitle: "Optional labels shared by the selected servers."
            )

            VStack(alignment: .leading, spacing: 8) {
                LabelPickerView(selectedLabels: $selectedLabels, labels: serverLabels)
            }
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
            if processing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Adding Torrent...")
                }
            } else {
                Label("Start Download", systemImage: "square.and.arrow.down.on.square")
            }
        }
    }

    var normalBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TorrentSummaryView(torrent: torrent)

                    Divider()

                    destinationSection

                    if !serverLabels.isEmpty {
                        Divider()
                        labelsSection
                    }
                }
                .padding(24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .disabled(processing)

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

    private struct SectionHeader: View {

        let title: String
        let subtitle: String

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    var body: some View {
        sharedBody
            .frame(minWidth: 500, idealWidth: 560, maxWidth: 640,
                   minHeight: 400, idealHeight: 500, maxHeight: 700)
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
