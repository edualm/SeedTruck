//
//  LocalTorrent+ComputedProperties.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Bencode
import Foundation

extension LocalTorrent {
    
    struct File {
        
        let path: String
        let size: Int
    }
    
    var name: String? {
        switch self {
        case .magnet(let magnet):
            return magnet.slice(from: "dn=", to: "&")?.replacingOccurrences(of: "+", with: " ")
            
        case .torrent(let torrent):
            guard let decoded = try? Bencoder().decode(bytes: [UInt8](torrent)) else {
                return nil
            }

            return decoded["info"]["name"].string
        }
    }
    
    var isPrivate: Bool? {
        switch self {
        case .magnet:
            return nil
            
        case .torrent(let torrent):
            guard let decoded = try? Bencoder().decode(bytes: [UInt8](torrent)) else {
                return nil
            }
            
            guard let result = decoded["info"]["private"].int else {
                return nil
            }
            
            return result == 1
        }
    }
    
    var files: [File]? {
        switch self {
        case .magnet:
            return nil
            
        case .torrent(let torrent):
            guard let decoded = try? Bencoder().decode(bytes: [UInt8](torrent)) else {
                return nil
            }
            
            guard let fileList = decoded["info"]["files"].list else {
                return nil
            }
            
            return fileList.compactMap {
                guard let pathComponents = $0["path"].list else {
                    return nil
                }
                
                let path = pathComponents
                    .compactMap { $0.string }
                    .joined(separator: "/")
                
                guard let length = $0["length"].int else {
                    return nil
                }
                
                return File(path: path, size: length)
            }
        }
    }
    
    var size: Int? {
        switch self {
        case .magnet:
            return nil

        case .torrent:
            guard let files = files else {
                return nil
            }
            
            return files.reduce(0) { $0 + $1.size }
        }
    }
}
