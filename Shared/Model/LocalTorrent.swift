//
//  LocalTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum LocalTorrent {
    
    case torrent(Data)
    case magnet(String)
}
