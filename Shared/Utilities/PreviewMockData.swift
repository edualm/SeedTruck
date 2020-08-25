//
//  PreviewMockData.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum PreviewMockData {
    
    static let localTorrentMagnet: LocalTorrent = .magnet("magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Fexplodie.org%3A6969&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&tr=udp%3A%2F%2Ftracker.empire-js.us%3A1337&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=wss%3A%2F%2Ftracker.btorrent.xyz&tr=wss%3A%2F%2Ftracker.fastcast.nz&tr=wss%3A%2F%2Ftracker.openwebtorrent.com&ws=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2F&xs=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2Fbig-buck-bunny.torrent")
    
    static let remoteTorrent = RemoteTorrent(id: "1",
                                             name: "Torrent #1",
                                             progress: 0.5,
                                             status: .downloading(peers: 1,
                                                                  peersSending: 1,
                                                                  peersReceiving: 0,
                                                                  downloadRate: 2448765,
                                                                  uploadRate: 125000),
                                             size: 1000000)
    
    static var server: Server {
        let server = Server()
        
        server.endpoint = URL(string: "http://endpoint/")!
        server.name = "Server #1"
        server.type = 0
        
        return server
    }
}
