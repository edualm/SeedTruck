//
//  Server.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

struct Server {
    
    let id: UUID
    let name: String
    
    var torrents: [RemoteTorrent]
}
