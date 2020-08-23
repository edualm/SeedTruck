//
//  SeedboxConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum ServerCommunicationError: Error {
    
    case notImplemented
    case notSupported
}

protocol ServerConnection {
    
    func addTorrent(_ torrent: LocalTorrent, completionHandler: (Result<RemoteTorrent, ServerCommunicationError>) -> ())
    func getTorrents(completionHandler: (Result<[RemoteTorrent], ServerCommunicationError>) -> ())
    func removeTorrent(_ torrent: RemoteTorrent, completionHandler: (Result<Bool, ServerCommunicationError>) -> ())
    func removeTorrent(byId id: String, completionHandler: (Result<Bool, ServerCommunicationError>) -> ())
}
