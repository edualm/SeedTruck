//
//  URLHandlerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct URLHandlerView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    let torrent: LocalTorrent
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Torrent Metadata")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(torrent.name ?? "N/A")
                            .foregroundColor(.secondary)
                    }
                }
                
                if serverConnections.count > 0 {
                    Section(header: Text("Server")) {
                        
                    }
                    
                    Section {
                        Button(action: {
                            
                        }) {
                            Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                        }
                    }
                } else {
                    GroupBox(label: Label("Oops!", systemImage: "exclamationmark.triangle")) {
                        HStack {
                            Text("You must first configure at least one server in the app in order to be able to add a torrent!")
                            Spacer()
                        }.padding(.top)
                    }
                }
            }
            .navigationTitle("Add Torrent")
            .navigationBarItems(trailing: Button(action: {
                self.presentation.wrappedValue.dismiss()
            }) {
                Text("Cancel")
                    .fontWeight(.medium)
            })
        }
    }
}

struct URLHandlerView_Previews: PreviewProvider {
    static var previews: some View {
        URLHandlerView(torrent: PreviewMockData.localTorrentMagnet)
    }
}
