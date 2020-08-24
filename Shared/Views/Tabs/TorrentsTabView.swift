//
//  TorrentsTabView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentsTabView: View {
    
    private struct AddMenuItem: Hashable {
        
        let name: String
        let systemImage: String
        let action: () -> ()
        
        static func == (lhs: TorrentsTabView.AddMenuItem, rhs: TorrentsTabView.AddMenuItem) -> Bool {
            lhs.name == rhs.name
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
    }
    
    private var addMenuItems: [AddMenuItem] {
        [
            .init(name: "Magnet Link", systemImage: "link") {
                //  TODO: Ask the user to input a magnet link...
            },
            .init(name: "Torrent File", systemImage: "doc") {
                let picker = DocumentPickerViewController(
                    torrentPickerWithOnPick: { url in
                        guard url.lastPathComponent.split(separator: ".").last == "torrent" else {
                            self.showingAddTorrentErrorAlert = true
                            
                            return
                        }
                        
                        guard let fileData = try? Data(contentsOf: url) else {
                            self.showingAddTorrentErrorAlert = true
                            
                            return
                        }
                        
                        selectedServer?.connection.addTorrent(.torrent(fileData)) { result in
                            if case Result.failure = result {
                                self.showingAddTorrentErrorAlert = true
                            }
                        }
                    },
                    onDismiss: {}
                )
                
                UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
            }
        ]
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    @State private var selectedServer: Server?
    @State private var showingAddTorrentErrorAlert = false
    
    //  TODO: Actually show an error alert!
    
    func onAppear() {
        selectedServer = serverConnections.first
    }
    
    var body: some View {
        NavigationView {
            TorrentListView(selectedServer: $selectedServer)
            .navigationTitle(selectedServer?.name ?? "Torrents")
            .navigationBarItems(leading: serverConnections.count > 1 ? AnyView(Menu {
                ForEach(serverConnections, id: \.self) { server in
                    Button {
                        selectedServer = server
                    } label: {
                        Text(server.name)
                        Image(systemName: "server.rack")
                    }
                }
            } label: {
                Image(systemName: "text.justify")
            }) : AnyView(EmptyView()), trailing: serverConnections.count > 0 ? AnyView(Menu {
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
            }) : AnyView(EmptyView()))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear(perform: onAppear)
    }
}

struct TorrentsTabView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsTabView()
        }
    }
}
