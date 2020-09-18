//
//  LocalTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation
import SwiftyBencode

enum LocalTorrent {
    
    case magnet(String)
    case torrent(data: Data, parsedTorrent: SwiftyBencode.Torrent)
}
