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
            
            case stopped
            case downloading
            case seeding
            case other
        }
        
        case stopped
        case downloading(peers: Int, peersSending: Int, peersReceiving: Int, downloadRate: Int, uploadRate: Int)
        case seeding(peers: Int, uploadRate: Int, ratio: Double, totalUploaded: Int64?)
        case other(_ status: String)
        
        var simple: Simple {
            switch self {
            case .stopped:
                return .stopped
                
            case .downloading:
                return .downloading
                
            case .seeding:
                return .seeding
                
            case .other:
                return .other
            }
        }
    }
    
    let id: String
    let name: String
    let progress: Double
    let status: Status
    let size: Int64
}
