//
//  LocalTorrent+ComputedProperties.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation
import SwiftyBencode

extension LocalTorrent {
    
    struct File {
        
        let path: String
        let size: Int
    }
    
    var name: String? {
        switch self {
        case .magnet(let magnet, _):
            return magnet.slice(from: "dn=", to: "&")?.replacingOccurrences(of: "+", with: " ")
            
        case .torrent(_, let parsedTorrent, _):
            return parsedTorrent.name
        }
    }
    
    var isPrivate: Bool? {
        switch self {
        case .magnet:
            return nil
            
        case .torrent(_, let parsedTorrent, _):
            return parsedTorrent.dictionary?["info"]?["private"]?.integer == 1
        }
    }
    
    var files: [File]? {
        switch self {
        case .magnet:
            return nil
            
        case .torrent(_, let parsedTorrent, _):
            return parsedTorrent.files.compactMap {
                let path = $0.path.joined(separator: "/")
                
                return File(path: path, size: $0.length)
            }
        }
    }
    
    var size: Int? {
        switch self {
        case .magnet:
            return nil

        case .torrent:
            guard let files = files else {
                return nil
            }
            
            return files.reduce(0) { $0 + $1.size }
        }
    }
}
