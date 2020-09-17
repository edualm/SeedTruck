//
//  RemoteTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

typealias Filter = RemoteTorrent.Status.Simple

struct RemoteTorrent: Identifiable {
    
    enum Status {
        
        enum Simple {
            
            case idle
            case downloading
            case seeding
        }
        
        case idle
        case downloading(peers: Int, peersSending: Int, peersReceiving: Int, downloadRate: Int, uploadRate: Int)
        case seeding(peers: Int, uploadRate: Int, ratio: Double, totalUploaded: Int?)
        
        var simple: Simple {
            switch self {
            case .idle:
                return .idle
                
            case .downloading:
                return .downloading
                
            case .seeding:
                return .seeding
            }
        }
    }
    
    let id: String
    let name: String
    let progress: Double
    let status: Status
    let size: Int
}
