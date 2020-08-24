//
//  TorrentsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct NoServersConfiguredView: View {
    
    var body: some View {
        VStack {
            Text("😞")
                .font(.largeTitle)
            Text("No servers configured!")
                .font(.headline)
                .padding()
            Text("Please add a server using the Settings tab.")
                .fontWeight(.light)
        }
    }
}

struct ServerConnectionErrorView: View {
    
    var body: some View {
        VStack {
            Text("😞")
                .font(.largeTitle)
            Text("Error!")
                .font(.headline)
                .padding()
            Text("Data could not be retrieved from the server.")
                .fontWeight(.light)
        }
    }
}

struct TorrentsView: View {
    
    private enum Status {
        case error
        case noError
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    @State private var selectedServer: Server?
    @State private var showingAddTorrentActionSheet = false
    @State private var status: Status = .noError
    @State private var timer: Timer? = nil
    @State private var torrents: [RemoteTorrent] = []
    
    func onAppear() {
        selectedServer = serverConnections.first
        
        updateData()
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            updateData()
        }
    }
    
    func onDisappear() {
        timer?.invalidate()
        timer = nil
    }
    
    func updateData() {
        if let server = selectedServer {
            server.connection.getTorrents { result in
                guard case let Result.success(torrents) = result else {
                    self.status = .error
                    self.torrents = []
                    
                    return
                }
                
                self.status = .noError
                self.torrents = torrents
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                switch status {
                case .error:
                    ServerConnectionErrorView()
                case .noError:
                    if selectedServer != nil {
                        List {
                            ForEach(torrents) { torrent in
                                ZStack {
                                    TorrentItemView(torrent: torrent)
                                        .padding(.all, 5)
                                    NavigationLink(destination: TorrentDetailsView(torrent: torrent)) {
                                        EmptyView()
                                    }.buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    } else {
                        NoServersConfiguredView()
                    }
                }
            }
            .navigationTitle(selectedServer?.name ?? "Torrents")
            .navigationBarItems(leading: Menu {
                ForEach(serverConnections, id: \.self) { server in
                    Button {
                        selectedServer = server
                        torrents = []
                        updateData()
                    } label: {
                        Text(server.name)
                        Image(systemName: "server.rack")
                    }
                }
            } label: {
                Image(systemName: "text.justify")
            }, trailing: serverConnections.count > 0 ? AnyView(Button(action: {
                showingAddTorrentActionSheet = true
            }) {
                Image(systemName: "link.badge.plus")
            }.actionSheet(isPresented: $showingAddTorrentActionSheet) {
                ActionSheet(title: Text("Add Torrent"), message: nil, buttons: [
                    .default(Text("Magnet Link")) { },
                    .default(Text("Torrent File")) {
                        let picker = DocumentPickerViewController(
                            torrentPickerWithOnPick: { url in
                                //  Success, check if the file is sane and upload it!
                            },
                            onDismiss: {}
                        )
                        
                        UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
                    },
                    .cancel()
                ])
            }) : AnyView(EmptyView()))
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
