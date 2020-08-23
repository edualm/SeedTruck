//
//  RemoteTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

struct RemoteTorrent: Identifiable {
    
    enum Status {
        
        case idle
        case downloading(peers: Int, peersSending: Int, peersReceiving: Int, downloadRate: Int, uploadRate: Int)
        case seeding(peers: Int, uploadRate: Int)
    }
    
    let id: String
    let name: String
    let progress: Double
    let status: Status
    let size: Int
}

extension RemoteTorrent.Status {
    
    var displayableStatus: String {
        switch self {
        case .idle:
            return "Idle"
            
        case .downloading:
            return "Downloading"
            
        case .seeding:
            return "Seeding"
        }
    }
}
