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
    
    func addTorrent(_ torrent: LocalTorrent, completionHandler: (Result<RemoteTorrent, ServerCommunicationError>) -> ())
    func getTorrents(completionHandler: @escaping (Result<[RemoteTorrent], ServerCommunicationError>) -> ())
    func removeTorrent(_ torrent: RemoteTorrent, completionHandler: (Result<Bool, ServerCommunicationError>) -> ())
    func removeTorrent(byId id: String, completionHandler: (Result<Bool, ServerCommunicationError>) -> ())
}

enum ServerType: String, CaseIterable {
    
    case transmission = "Transmission"
    
    init?(fromCode code: Int) {
        switch code {
        case 0:
            self = .transmission
            
        default:
            return nil
        }
    }
    
    var code: Int {
        switch self {
        case .transmission:
            return 0
        }
    }
}
