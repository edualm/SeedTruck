//
//  TorrentListView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct TorrentListView: View {
    
    private enum Status {
        
        case loading
        
        case error
        case noError
    }
    
    @Binding var selectedServer: Server?
    
    @State private var status: Status = .noError
    @State private var timer: Timer? = nil
    @State private var torrents: [RemoteTorrent] = []
    
    func updateData() {
        if let server = selectedServer {
            server.connection.getTorrents { result in
                guard case let Result.success(torrents) = result else {
                    self.status = .error
                    self.torrents = []
                    
                    return
                }
                
                self.status = .noError
                self.torrents = torrents.sorted { $0.name < $1.name }
            }
        }
    }
    
    func onAppear() {
        updateData()
        
        #if os(watchOS)
        let refreshInterval = 10.0
        #else
        let refreshInterval = 2.0
        #endif
        
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            updateData()
        }
    }
    
    func onDisappear() {
        timer?.invalidate()
        timer = nil
    }
    
    #if os(iOS)
    static private let listStyle = InsetGroupedListStyle()
    #else
    static private let listStyle = DefaultListStyle()
    #endif
    
    var body: some View {
        Group {
            switch status {
            case .error:
                ServerConnectionErrorView()
                
            case .loading:
                LoadingView()
                
            case .noError:
                if selectedServer != nil {
                    VStack {
                        #if os(watchOS)
                        ServerStatusViewSmall(torrents: torrents)
                        #endif
                        
                        List {
                            ForEach(torrents) { torrent in
                                ZStack {
                                    #if os(tvOS)
                                    NavigationLink(destination: TorrentDetailsView(torrent: torrent,
                                                                                   actionHandler: .init(server: selectedServer!,
                                                                                                        torrent: torrent))) {
                                        TorrentItemView(torrent: torrent)
                                            .padding(.all, 5)
                                    }
                                    #else
                                    TorrentItemView(torrent: torrent)
                                        .padding(.all, 5)
                                    NavigationLink(destination: TorrentDetailsView(torrent: torrent,
                                                                                   actionHandler: .init(server: selectedServer!,
                                                                                                        torrent: torrent))) {
                                        EmptyView()
                                    }.buttonStyle(PlainButtonStyle())
                                    #endif
                                }
                            }
                        }
                        .listStyle(Self.listStyle)
                        
                        #if !os(watchOS)
                        ServerStatusView(torrents: torrents)
                        #endif
                    }
                } else {
                    NoServersConfiguredView()
                }
            }
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onChange(of: selectedServer) { _ in
            status = .loading
        }
    }
}

struct TorrentListView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentListView(selectedServer: .constant(PreviewMockData.server))
    }
}
