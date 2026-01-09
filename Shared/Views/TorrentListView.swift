//
//  TorrentListView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct TorrentListView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sharedBucket: SharedBucket
    @Environment(\.isSearching) private var isSearching
    
    private enum Status {
        
        case loading
        
        case error
        case noError
    }
    
    @Binding var server: Server?
    @Binding var filter: Filter?
    @Binding var filterQuery: String
    @Binding var selectedTorrentId: String?
    
    @State private var status: Status = .noError
    @State private var timer: Timer? = nil
    @State private var torrents: [RemoteTorrent] = []
    
    #if os(watchOS)
    let refreshInterval: Int = 10
    #else
    @AppStorage(Constants.StorageKeys.autoUpdateInterval) var refreshInterval: Int = 2
    #endif
    
    func updateData() {
        if let server = server {
            server.connection.getTorrents { result in
                guard server == self.server else {
                    return
                }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let torrents):
                        self.status = .noError
                        self.torrents = torrents.sorted { $0.name < $1.name }
                        self.sharedBucket.torrents = self.torrents
                    case .failure:
                        self.status = .error
                        self.torrents = []
                        self.sharedBucket.torrents = []
                    }
                }
            }
        }
    }
    
    func invalidateTimer() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    func onAppear() {
        updateData()
        invalidateTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval), repeats: true) { _ in
            updateData()
        }
    }
    
    func onDisappear() {
        invalidateTimer()
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
                ErrorView(type: .noConnection)
                
            case .loading:
                LoadingView()
                
            case .noError:
                if server != nil {
                    let filteredTorrents = torrents.filter {
                        let compliesToQuery = filterQuery != "" ?
                            $0.name.lowercased().contains(filterQuery.lowercased()) :
                            true
                        
                        guard let filter = filter else {
                            return compliesToQuery
                        }
                        
                        return compliesToQuery && $0.status.simple == filter
                    }
                    
                    VStack {
                        #if os(watchOS)
                        ServerStatusView(torrents: torrents)
                        #endif
                        
                        if filteredTorrents.count > 0 {
                            List {
                                ForEach(filteredTorrents) { torrent in
                                    ZStack {
                                        #if os(macOS)
                                        NavigationLink(
                                            destination: TorrentDetailsViewWrapper(
                                                torrent: torrent,
                                                server: server!,
                                                selectedTorrentId: $selectedTorrentId
                                            )
                                            .id(torrent.id),
                                            tag: torrent.id,
                                            selection: $selectedTorrentId
                                        ) {
                                            TorrentItemView(torrent: torrent)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 5)
                                        }
                                        #elseif os(tvOS)
                                        NavigationLink(destination: TorrentDetailsView(torrent: torrent,
                                                                                       presenter: .init(server: server!,
                                                                                                        torrent: torrent))) {
                                            TorrentItemView(torrent: torrent)
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 5)
                                        }
                                        #else
                                        TorrentItemView(torrent: torrent)
                                            .padding(.all, 5)
                                        NavigationLink(destination: TorrentDetailsView(torrent: torrent,
                                                                                       presenter: .init(server: server!,
                                                                                                        torrent: torrent))) {
                                            EmptyView()
                                        }
                                        .opacity(0.0)
                                        .buttonStyle(PlainButtonStyle())
                                        #endif
                                    }
                                }
                            }
                            #if os(iOS)
                            .padding(.top, isSearching ? -32 : 0)
                            #endif
                            .animation(.easeInOut(duration: 0.2), value: isSearching)
                            .listStyle(Self.listStyle)
                        } else {
                            NoTorrentsView()
                                .padding()
                        }
                        
                        #if !os(watchOS)
                        if #unavailable(iOS 26.0) {
                            ServerStatusView(torrents: torrents)
                        }
                        #endif
                        
                        #if os(macOS)
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
        .onReceive(NotificationCenter.default.publisher(for: .updateTorrentListView)) { _ in
            onAppear()
        }
    }
}

struct TorrentListView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentListView(server: .constant(PreviewMockData.server), filter: .constant(nil), filterQuery: .constant(""), selectedTorrentId: .constant(nil))
    }
}
