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
    
    func addTorrent(_ torrent: LocalTorrent) -> Result<RemoteTorrent, ServerCommunicationError>
    func getTorrents() -> Result<[RemoteTorrent], ServerCommunicationError>
    func removeTorrent(_ torrent: RemoteTorrent) -> Result<Bool, ServerCommunicationError>
    func removeTorrent(byId id: String) -> Result<Bool, ServerCommunicationError>
}
