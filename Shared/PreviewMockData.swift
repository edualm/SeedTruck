//
//  PreviewMockData.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum PreviewMockData {
    
    static let torrent = RemoteTorrent(id: "1",
                                            name: "Torrent #1",
                                            progress: 0.5,
                                            status: .downloading(peers: 1,
                                                                 peersSending: 1,
                                                                 peersReceiving: 0,
                                                                 downloadRate: 2448765,
                                                                 uploadRate: 125000),
                                            size: 1000000)
    
    static let server = Server(id: UUID(),
                               name: "Server #1",
                               connectionDetails: .init(type: .transmission, endpoint: URL(string: "http://endpoint/")!, credentials: nil),
                               torrents: [torrent])
}
