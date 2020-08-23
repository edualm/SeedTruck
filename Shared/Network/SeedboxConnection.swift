//
//  SeedboxConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum SeedboxCommunicationError: Error {
    case notImplemented
    case notSupported
}

protocol SeedboxConnection {
    
    func addTorrent(_ torrent: LocalTorrent) -> Result<RemoteTorrent, SeedboxCommunicationError>
    func getTorrents() -> Result<[RemoteTorrent], SeedboxCommunicationError>
    func removeTorrent(_ torrent: RemoteTorrent) -> Result<Bool, SeedboxCommunicationError>
    func removeTorrent(byId id: String) -> Result<Bool, SeedboxCommunicationError>
}
