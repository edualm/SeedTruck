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
                                            status: .downloading(peers: 1,
                                                                 peersSending: 1,
                                                                 peersReceiving: 0,
                                                                 downloadRate: FileTransmissionSpeed(bytesPerSecond: 100),
                                                                 uploadRate: FileTransmissionSpeed(bytesPerSecond: 10)),
                                            size: FileSize(bytes: 1000000))
    
    static let server = Server(id: UUID(), name: "Server #1", torrents: [torrent])
}
