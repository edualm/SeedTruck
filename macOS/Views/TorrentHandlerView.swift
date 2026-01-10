//
//  TorrentHandlerView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct TorrentHandlerView: View {
    
    typealias CloseHandler = () -> ()
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    @State var errorMessage: String? = nil
    @State var processing: Bool = false
    @State var selectedServers: [Server] = []
    @State var serverLabels: [String] = []
    @State var selectedLabels: [String] = []
    
    let torrent: LocalTorrent
    let server: Server?
    let closeHandler: CloseHandler?
    
    var serverBindings: [Binding<Bool>] {
        serverConnections.map { server in
            if selectedServers.contains(server) {
                return Binding<Bool>(
                    get: { true },
                    set: { _ in selectedServers.removeAll { $0 == server } }
                )
            } else {
                return Binding<Bool>(
                    get: { false },
                    set: { _ in selectedServers.append(server) }
                )
            }
        }
    }
    
    var normalBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Torrent Metadata Section
            GroupBox(label: Label("Torrent Metadata", systemImage: "doc.text").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    if let name = torrent.name {
                        MetadataRow(label: "Name", value: name)
                    }
                    
                    if let size = torrent.size {
                        MetadataRow(label: "Size", value: ByteCountFormatter.humanReadableFileSize(bytes: Int64(size)))
                    }
                    
                    if let files = torrent.files {
                        MetadataRow(label: "Files", value: "\(files.count)")
                    }
                    
                    if let isPrivate = torrent.isPrivate {
                        MetadataRow(label: "Private", value: isPrivate ? "Yes" : "No")
                    }
                }
                .padding(10)
            }
            
            // Labels Section
            if !serverLabels.isEmpty {
                GroupBox(label: Label("Labels (Optional)", systemImage: "tag").font(.headline)) {
                    VStack(alignment: .leading, spacing: 4) {
                        LabelPickerView(selectedLabels: $selectedLabels, labels: serverLabels)
                    }
                    .padding(10)                    
                }
            }
            
            // Server Selection Section
            if server == nil {
                if serverConnections.count > 0 {
                    GroupBox(label: Label("Server(s)", systemImage: "server.rack").font(.headline)) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(0 ..< serverConnections.count, id: \.self) { index in
                                Toggle(isOn: serverBindings[index]) {
                                    Text(serverConnections[index].name)
                                        .foregroundColor(.primary)
                                }
                                .toggleStyle(.checkbox)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                    }
                } else {
                    NoServersWarningView()
                }
            }
            
            Spacer(minLength: 0)
            
            // Action Button
            if serverConnections.count > 0 {
                HStack {
                    Spacer()
                    Button(action: startDownload) {
                        Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedServers.count == 0)
                    Spacer()
                }
            }
        }
        .padding(16)
        .alert(isPresented: showingError) {
            Alert(title: Text("Error!"), message: Text(errorMessage!), dismissButton: .default(Text("Ok")))
        }
    }
    
    struct MetadataRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .frame(width: 70, alignment: .leading)
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text(value)
                    .foregroundColor(.primary)
                    .font(.system(size: 12))
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
        }
    }
    
    var body: some View {
        sharedBody
            .frame(minWidth: 450, idealWidth: 520, maxWidth: 800,
                   minHeight: 350, idealHeight: 420, maxHeight: 700)
    }
    
    func loadLabelsFromServer() {
        guard let serverToUse = server ?? selectedServers.first else {
            return
        }
        
        serverToUse.connection.getTorrents { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let torrents):
                    let allLabels = torrents.flatMap { $0.labels }
                    serverLabels = Array(Set(allLabels)).sorted()
                    
                case .failure(_):
                    ()
                }
            }
        }
    }
}

struct TorrentHandlerNavigationView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    let torrent: LocalTorrent
    let server: Server?
    
    func closeHandler() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
        }
        
        Application.closeMainWindow()
    }
    
    func onDisappear() {
        NSDocumentController().clearRecentDocuments(nil)
    }
    
    var body: some View {
        TorrentHandlerView(torrent: torrent,
                           server: server,
                           closeHandler: closeHandler)
            .onDisappear(perform: onDisappear)
    }
}

struct TorrentHandlerNavigationView_Previews: PreviewProvider {

    static var previews: some View {
        TorrentHandlerNavigationView(torrent: PreviewMockData.localTorrentMagnet,
                                     server: nil)
    }
}
