//
//  MainView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    var body: some View {
        TabView {
            ForEach(serverConnections, id: \.self) { server in
                NavigationView {
                    TorrentListView(server: .constant(server), filter: .constant(nil))
                }.tabItem {
                    Image(systemName: "server.rack")
                    Text(server.name)
                }
            }
            SettingsView(presenter: SettingsPresenter(managedObjectContext: managedObjectContext))
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Settings")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView()
    }
}
