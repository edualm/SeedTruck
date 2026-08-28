//
//  LocalTorrent+ComputedProperties.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

extension LocalTorrent {

    var name: String? {
        switch self {
        case .magnet(let magnet, _):
            return magnet.slice(from: "dn=", to: "&")?.replacingOccurrences(of: "+", with: " ")
            
        case .torrent(_, let metadata, _):
            return metadata.name
        }
    }
    
    var isPrivate: Bool? {
        switch self {
        case .magnet:
            return nil
            
        case .torrent(_, let metadata, _):
            return metadata.isPrivate
        }
    }
    
    var files: [File]? {
        switch self {
        case .magnet:
            return nil
            
        case .torrent(_, let metadata, _):
            return metadata.files
        }
    }
    
    var size: Int64? {
        switch self {
        case .magnet:
            return nil

        case .torrent(_, let metadata, _):
            return metadata.totalSize
        }
    }
}
