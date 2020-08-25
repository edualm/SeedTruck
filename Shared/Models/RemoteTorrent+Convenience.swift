//
//  RemoteTorrent+Convenience.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

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

extension Array where Iterator.Element == RemoteTorrent {
    
    var downloadSpeed: Int {
        self.reduce(0) {
            switch $1.status {
            case let .downloading(_, _, _, speed, _):
                return $0 + speed
                
            default:
                return $0
            }
        }
    }
    
    var uploadSpeed: Int {
        self.reduce(0) {
            switch $1.status {
            case let .downloading(_, _, _, _, speed), let .seeding(_, speed):
                return $0 + speed
                
            default:
                return $0
            }
        }
    }
}