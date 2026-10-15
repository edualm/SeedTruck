//
//  MainView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @EnvironmentObject private var serverRepository: ServerRepository

    private var serverConnections: [Server] { serverRepository.servers }
    
    @State private var selectedServerID: UUID?
    
    #if DEBUG
    @State private var showcaseTorrent: RemoteTorrent?
    #endif
    
    private func reconcileSelection(with serverIDs: [UUID]) {
        if let selectedServerID, serverIDs.contains(selectedServerID) {
            return
        }

        selectedServerID = serverIDs.first
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if serverConnections.count > 0 {
                    ScrollView {
                        ForEach(serverConnections) { server in
                            Button(action: {
                                selectedServerID = server.id
                            }, label: {
                                Label(server.name, systemImage: "server.rack")
                            })
                        }
                    }
                    .navigationBarTitle("Servers")
                } else {
                    NoServersConfiguredView()
                        .navigationBarTitle("Error!")
                }
            }
            .navigationDestination(item: $selectedServerID) { serverID in
                if let server = serverConnections.first(where: { $0.id == serverID }) {
                    ServerView(
                        server: server,
                        shouldShowBackButton: serverConnections.count > 1
                    )
                } else {
                    NoServersConfiguredView()
                }
            }
            #if DEBUG
            .navigationDestination(item: $showcaseTorrent) { torrent in
                if let server = serverConnections.first {
                    TorrentDetailsViewWrapper(torrent: torrent, server: server)
                }
            }
            #endif
        }
        .onAppear {
            reconcileSelection(with: serverConnections.map(\.id))
        }
        .onChange(of: serverConnections.map(\.id)) { _, serverIDs in
            reconcileSelection(with: serverIDs)
        }
        #if DEBUG
        .task {
            if await Showcase.stage(.details, when: { selectedServerID != nil }),
               let server = serverConnections.first,
               let id = Showcase.state?.selectedTorrent {
                // As a tap on the torrent's row would, once the server's list is up.
                await Showcase.pause(1.5)
                showcaseTorrent = try? await server.connection.getTorrent(id: id)
                await Showcase.finish(after: 2)
            }
        }
        #endif
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView()
            .environmentObject(PreviewMockData.serverRepository)
    }
}
