//
//  LocalTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Bencode
import Foundation

enum LocalTorrent {
    
    case magnet(String)
    case torrent(Data)
}

extension LocalTorrent {
    
    var name: String? {
        switch self {
        case .magnet(let magnet):
            return magnet.slice(from: "dn=", to: "&")?.replacingOccurrences(of: "+", with: " ")
            
        case .torrent(let torrent):
            guard let decoded = try? Bencoder().decode(bytes: torrent.map { $0 }) else {
                return nil
            }
            
            return decoded["info"]["name"].string
        }
    }
}
