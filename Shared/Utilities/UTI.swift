//
//  UTI.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/11/2020.
//

import UniformTypeIdentifiers

enum UTI {
    
    static var torrent: UTType {
        UTType(exportedAs: "io.edr.seedtruck.torrent")
    }
}
