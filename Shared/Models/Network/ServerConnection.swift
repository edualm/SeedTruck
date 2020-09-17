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
    case parseError
    case serverError(String?)
}

protocol ServerConnection {
    
    func test(completionHandler: @escaping (Bool) -> ())
    
    func addTorrent(_ torrent: LocalTorrent, completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ())
    func getTorrent(id: String, completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ())
    func getTorrents(completionHandler: @escaping (Result<[RemoteTorrent], ServerCommunicationError>) -> ())
    func removeTorrent(_ torrent: RemoteTorrent, deletingData: Bool, completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ())
}
