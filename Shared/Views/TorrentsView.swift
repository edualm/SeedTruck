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
    
    private struct AddMenuItem: Hashable {
        
        let name: String
        let systemImage: String
        let action: () -> ()
        
        static func == (lhs: TorrentsView.AddMenuItem, rhs: TorrentsView.AddMenuItem) -> Bool {
            lhs.name == rhs.name
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
    }
    
    private var addMenuItems: [AddMenuItem] = [
        .init(name: "Magnet Link", systemImage: "link") {
            
        },
        .init(name: "Torrent File", systemImage: "doc") {
            let picker = DocumentPickerViewController(
                torrentPickerWithOnPick: { url in
                    //  Success, check if the file is sane and upload it!
                },
                onDismiss: {}
            )
            
            UIApplication.shared.windows.first?.rootViewController?.present(picker, animated: true)
        }
    ]
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    @State private var selectedServer: Server?
    @State private var showingAddTorrentActionSheet = false
    
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

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
