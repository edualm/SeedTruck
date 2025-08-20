//
//  LocalTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation
import SwiftyBencode

enum LocalTorrent {
    
    case magnet(String, labels: [String] = [])
    case torrent(data: Data, parsedTorrent: SwiftyBencode.Torrent, labels: [String] = [])
    
    var labels: [String] {
        switch self {
        case .magnet(_, let labels):
            return labels
        case .torrent(_, _, let labels):
            return labels
        }
    }
    
    func withLabels(_ labels: [String]) -> LocalTorrent {
        switch self {
        case .magnet(let magnet, _):
            return .magnet(magnet, labels: labels)
        case .torrent(let data, let parsedTorrent, _):
            return .torrent(data: data, parsedTorrent: parsedTorrent, labels: labels)
        }
    }
}
