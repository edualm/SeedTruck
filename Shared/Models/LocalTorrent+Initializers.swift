//
//  LocalTorrent+Initializers.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

extension LocalTorrent {
    
    init?(url: URL) {
        if url.isFileURL {
            guard url.lastPathComponent.split(separator: ".").last == "torrent" else {
                return nil
            }
            
            do {
                self = .torrent(try Data(contentsOf: url))
            } catch {
                return nil
            }
        } else {
            let urlString = url.absoluteString
            
            guard urlString.hasPrefix("magnet:") else {
                return nil
            }
            
            self = .magnet(urlString)
        }
    }
}
