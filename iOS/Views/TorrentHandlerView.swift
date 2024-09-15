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
    
    let torrent: LocalTorrent
    let server: Server?
    let closeHandler: CloseHandler?
    
    var normalBody: some View {
        Form {
            Section(header: Text("Torrent Metadata")) {
                InfoSectionView(torrent: torrent)
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
