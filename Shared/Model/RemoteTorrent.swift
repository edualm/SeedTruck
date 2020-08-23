//
//  RemoteTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

struct RemoteTorrent {
    
    enum Status {
        case idle
        case downloading(peers: Int, peersSending: Int, peersReceiving: Int, downloadRate: FileTransmissionSpeed, uploadRate: FileTransmissionSpeed)
        case seeding(peers: Int, uploadRate: FileTransmissionSpeed)
        
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
    
    let id: String
    let name: String
    let status: Status
    let size: FileSize
}

extension RemoteTorrent: Identifiable {}
