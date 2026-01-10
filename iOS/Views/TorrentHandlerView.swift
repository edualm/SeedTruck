//
//  TorrentHandlerView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 25/08/2020.
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
    @State var selectedLabels: [String] = []
    @State var serverLabels: [String] = []
    
    let torrent: LocalTorrent
    let server: Server?
    let closeHandler: CloseHandler?
    
    var normalBody: some View {
        Form {
            Section {
                HStack {
                    Label("Confirm and Edit", systemImage: "checkmark.circle")
                        .font(.headline)
                    Spacer()
                }.padding(.vertical, 4)
                Text("Confirm the data matches what you expect, add labels to your torrent (if you want to and they exist on your server), and start the download!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section(header: Text("Torrent Metadata")) {
                InfoSectionView(torrent: torrent)
            }
            
            if !serverLabels.isEmpty {
                Section(header: Text("Labels")) {
                    LabelPickerView(selectedLabels: $selectedLabels, labels: serverLabels)
                }
            }
            
            if server == nil {
                if serverConnections.count > 0 {
                    Section(header: Text("Server(s)")) {
                        ForEach(0 ..< serverConnections.count, id: \.self) { index in
                            Button(action: {
                                let server = serverConnections[index]
                                
                                if selectedServers.contains(server) {
                                    selectedServers.removeAll { $0 == server }
                                } else {
                                    selectedServers.append(server)
                                }
                            }) {
                                HStack {
                                    Text(serverConnections[index].name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedServers.contains(serverConnections[index]) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    NoServersWarningView()
                }
            }
            
            if serverConnections.count > 0 {
                Section {
                    Button(action: startDownload) {
                        Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                    }.disabled(selectedServers.count == 0)
                }
            }
        }
        .alert(isPresented: showingError) {
            Alert(title: Text("Error!"), message: Text(errorMessage!), dismissButton: .default(Text("Ok")))
        }
    }
    
    var body: some View {
        sharedBody
            .navigationBarItems(trailing: Button(action: { closeHandler?() }) {
                Text("Cancel")
                    .fontWeight(.medium)
            })
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
        
        presentation.wrappedValue.dismiss()
    }
    
    var body: some View {
        NavigationView {
            TorrentHandlerView(torrent: torrent,
                               server: server,
                               closeHandler: closeHandler)
        }
    }
}

struct TorrentHandlerNavigationView_Previews: PreviewProvider {

    static var previews: some View {
        TorrentHandlerNavigationView(torrent: PreviewMockData.localTorrentMagnet,
                                     server: nil)
    }
}
