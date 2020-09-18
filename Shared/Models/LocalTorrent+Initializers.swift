//
//  LocalTorrent+Initializers.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation
import SwiftyBencode

extension LocalTorrent {
    
    init?(url: URL) {
        if url.isFileURL {
            guard url.lastPathComponent.split(separator: ".").last == "torrent" else {
                return nil
            }
            
            guard let data = try? Data(contentsOf: url), let parsedTorrent = Torrent(data: data) else {
                return nil
            }
            
            self = .torrent(data: data, parsedTorrent: parsedTorrent)
            
        } else {
            let urlString = url.absoluteString
            
            guard urlString.hasPrefix("magnet:") else {
                return nil
            }
            
            self = .magnet(urlString)
        }
    }
}
