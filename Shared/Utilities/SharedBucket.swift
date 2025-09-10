//
//  SharedBucket.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 18/09/2020.
//

import Foundation

class SharedBucket: ObservableObject {
    
    @Published var torrents: [RemoteTorrent] = []
    var dataTransferManager: DataTransferManageable?
    
    init() {}
}

