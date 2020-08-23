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
    
    @StateObject var presenter: TorrentsViewPresenter = TorrentsViewPresenter()
    
    var body: some View {
        NavigationView {
            Group {
                if let server = presenter.viewModel.currentServer {
                    List {
                        ForEach(server.torrents) { torrent in
                            ZStack {
                                TorrentItemView(name: torrent.name, progress: 0.1)
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
            
            .navigationTitle("Torrents")
            .navigationBarItems(leading: presenter.viewModel.servers.count > 1 ? AnyView(Button(action: {
                presenter.perform(.toggleChangeSeedboxListVisibility)
            }) {
                Image(systemName: "text.justify")
            }) : AnyView(EmptyView()), trailing: presenter.viewModel.currentServer != nil ? AnyView(Button(action: {
                presenter.perform(.addTorrent)
            }) {
                Image(systemName: "plus")
            }) : AnyView(EmptyView()))
        }
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
            TorrentsView(presenter: TorrentsViewPresenter(viewModel: .init(servers: [PreviewMockData.server],
                                                                           currentServer: PreviewMockData.server)))
        }
    }
}
