//
//  SettingsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct SettingsView: View {
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("Server #1")) {
                        Label("Connection Successful!", systemImage: "checkmark")
                            .foregroundColor(.green)
                        NavigationLink(destination: EmptyView()) {
                            Label("Edit", systemImage: "pencil")
                        }
                        NavigationLink(destination: EmptyView()) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    Section {
                        NavigationLink(destination: EmptyView()) {
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
