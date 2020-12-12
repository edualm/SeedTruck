//
//  ServerSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct ServerSettingsView: View {
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(serverConnections) { server in
                        NavigationLink(destination: ServerDetailsView(server: server)) {
                            Label(server.name, systemImage: "server.rack")
                        }
                    }
                    Divider()
                    NavigationLink(destination: NewServerView()) {
                        Label("New Server", systemImage: "plus.app")
                    }
                }
            }
        }
    }
}

struct ServerSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerSettingsView()
    }
}
