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

struct TorrentsView: View {
    
    @EnvironmentObject var engine: Engine
    
    @State var selectedServer: Server?
    
    func onAppear() {
        if engine.servers.count != 0 {
            selectedServer = engine.servers[0]
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if let server = selectedServer {
                    List {
                        ForEach(server.torrents) { torrent in
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
            .navigationTitle(selectedServer?.name ?? "Torrents")
            .navigationBarItems(leading: Menu {
                ForEach(engine.servers, id: \.self) { server in
                    Button {
                        self.selectedServer = server
                    } label: {
                        Text(server.name)
                        Image(systemName: "desktopcomputer")
                    }
                }
            } label: {
                 Image(systemName: "text.justify")
            }, trailing: engine.servers.count > 0 ? AnyView(Button(action: {
                //  Add Torrent...
            }) {
                Image(systemName: "plus")
            }) : AnyView(EmptyView()))
        }.onAppear(perform: onAppear)
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
