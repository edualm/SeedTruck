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
        Form {
            Section(header: Text("Torrent Metadata").font(.largeTitle).padding(.bottom, 8)) {
                InfoSectionView(torrent: torrent)
            }
            
            Divider()
                .padding([.top, .bottom])
            
            if server == nil {
                if serverConnections.count > 0 {
                    Section(header: Text("Server(s)").font(.largeTitle)) {
                        ForEach(0 ..< serverConnections.count) { index in
                            Toggle(isOn: serverBindings[index]) {
                                Text(serverConnections[index].name)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } else {
                    NoServersWarningView()
                }
            }
            
            Divider()
                .padding([.top, .bottom])
            
            if serverConnections.count > 0 {
                Section {
                    Button(action: startDownload) {
                        Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                    }.disabled(selectedServers.count == 0)
                }.centered()
            }
        }
        .alert(isPresented: showingError) {
            Alert(title: Text("Error!"), message: Text(errorMessage!), dismissButton: .default(Text("Ok")))
        }
    }
    
    var body: some View {
        sharedBody
            .frame(minWidth: 500,
                   minHeight: (torrent.size != nil ? 300 : 260) + CGFloat(serverConnections.count * 15))
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
