//
//  SettingsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct SettingsView: View {
    
    @FetchRequest(
        entity: ServerConnectionDetails.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ServerConnectionDetails.credentialUsername, ascending: true)
        ]
    ) var serverConnections: FetchedResults<ServerConnectionDetails>
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(serverConnections) {
                        Section(header: Text($0.name)) {
                            Label("Connection Successful!", systemImage: "checkmark")
                                .foregroundColor(.green)
                            NavigationLink(destination: EmptyView()) {
                                Label("Edit", systemImage: "pencil")
                            }
                            NavigationLink(destination: EmptyView()) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: NewServerView()) {
                            Text("New Server")
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Settings")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        SettingsView()
            
    }
}
