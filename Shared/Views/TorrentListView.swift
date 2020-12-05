//
//  TorrentListView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct TorrentListView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    
    private enum Status {
        
        case loading
        
        case error
        case noError
    }
    
    @Binding var server: Server?
    @Binding var filter: Filter?
    
    @State private var status: Status = .noError
    @State private var timer: Timer? = nil
    @State private var torrents: [RemoteTorrent] = []
    
    func updateData() {
        if let server = server {
            server.connection.getTorrents { result in
                guard case let Result.success(torrents) = result else {
                    self.status = .error
                    self.torrents = []
                    
                    return
                }
                
                self.status = .noError
                self.torrents = torrents
                    .sorted { $0.name < $1.name }
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
        
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        
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
                if server != nil {
                    let filteredTorrents = torrents.filter {
                        guard let filter = filter else {
                            return true
                        }
                        
                        return $0.status.simple == filter
                    }
                    
                    VStack {
                        #if os(watchOS)
                        ServerStatusView(torrents: torrents)
                        #endif
                        
                        if filteredTorrents.count > 0 {
                            List {
                                ForEach(filteredTorrents) { torrent in
                                    ZStack {
                                        #if os(macOS) || os(tvOS)
                                        NavigationLink(destination: TorrentDetailsView(torrent: torrent,
                                                                                       presenter: .init(server: server!,
                                                                                                        torrent: torrent))) {
                                            TorrentItemView(torrent: torrent)
                                                .padding(.all, 5)
                                        }
                                        #else
                                        TorrentItemView(torrent: torrent)
                                            .padding(.all, 5)
                                        NavigationLink(destination: TorrentDetailsView(torrent: torrent,
                                                                                       presenter: .init(server: server!,
                                                                                                        torrent: torrent))) {
                                            EmptyView()
                                        }.buttonStyle(PlainButtonStyle())
                                        #endif
                                    }
                                }
                            }
                            .listStyle(Self.listStyle)
                        } else {
                            NoTorrentsView()
                                .padding()
                        }
                        
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
        .onChange(of: server) { _ in
            status = .loading
            
            updateData()
        }
        .onChange(of: scenePhase) {
            switch $0 {
            case .active:
                onAppear()
                
            case .background, .inactive:
                onDisappear()
                
            @unknown default:
                ()
            }
        }
    }
}

struct TorrentListView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentListView(server: .constant(PreviewMockData.server), filter: .constant(nil))
    }
}
