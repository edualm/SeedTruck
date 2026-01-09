//
//  MainView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    @State private var selectedServer: Server?
    
    func onAppear() {
        if selectedServer == nil {
            selectedServer = serverConnections.first
        }
    }
    
    var body: some View {
        NavigationStack {
            if serverConnections.count > 0 {
                ScrollView {
                    ForEach(serverConnections) { server in
                        Button(action: {
                            selectedServer = server
                        }, label: {
                            Label(server.name, systemImage: "server.rack")
                        })
                    }
                }
                .navigationBarTitle("Servers")
                .navigationDestination(isPresented: Binding(
                    get: { selectedServer != nil },
                    set: { if !$0 { selectedServer = nil } }
                )) {
                    if let selectedServer = selectedServer {
                        ServerView(server: .constant(selectedServer),
                                   shouldShowBackButton: serverConnections.count > 1)
                    }
                }
            } else {
                NoServersConfiguredView()
                    .navigationBarTitle("Error!")
            }
        }
        .onAppear(perform: onAppear)
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView()
    }
}
