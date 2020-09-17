//
//  ConnectionDetails.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/09/2020.
//

import Foundation

struct ConnectionDetails {
    
    let type: ServerType
    let endpoint: URL
    let credentials: (username: String, password: String)?
}
