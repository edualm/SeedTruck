//
//  SettingsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct SettingsView: View {
    
    private enum ConnectionResult {
        case connecting
        
        case success
        case failure
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    @State private var showingNewServer = false
    @State private var connectionResults: [Server: ConnectionResult] = [:]
    
    func onAppear() {
        connectionResults = serverConnections.reduce(into: [Server: ConnectionResult]()) {
            $0[$1] = .connecting
        }
        
        serverConnections.forEach { server in
            server.connection.test { success in
                DispatchQueue.main.async {
                    connectionResults[server] = success ? .success : .failure
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(serverConnections) { server in
                        Section(header: Text(server.name)) {
                            switch connectionResults[server] {
                            case .connecting:
                                Label("Testing...", systemImage: "bolt.horizontal.circle")
                                    .foregroundColor(.gray)
                            case .success:
                                Label("Connection Successful!", systemImage: "checkmark.circle")
                                    .foregroundColor(.green)
                            case .failure:
                                Label("Connection Failed!", systemImage: "xmark.circle")
                                    .foregroundColor(.red)
                            case .none:
                                EmptyView()
                            }
                            NavigationLink(destination: EmptyView()) {
                                Label("Edit", systemImage: "rectangle.and.pencil.and.ellipsis")
                            }
                            NavigationLink(destination: EmptyView()) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: NewServerView(showing: $showingNewServer), isActive: $showingNewServer) {
                            Text("New Server")
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Settings")
        }.onAppear(perform: onAppear)
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        SettingsView()
            
    }
}
