//
//  LocalTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum LocalTorrent {
    
    case magnet(String)
    case torrent(Data)
}
