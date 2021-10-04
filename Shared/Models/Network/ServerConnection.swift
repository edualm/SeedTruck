//
//  SeedboxConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

extension RemoteTorrent {
    
    enum Action {
        case pause
        case remove(deletingData: Bool)
        case start
    }
}

enum ServerCommunicationError: Error {
    
    case notImplemented
    case notSupported
    case parseError
    case serverError(String?)
}

protocol ServerConnection {
    
    func test(completionHandler: @escaping (Bool) -> ())
    
    #if os(iOS) || os(macOS)
    func addTorrent(_ torrent: LocalTorrent, completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ())
    #endif
    
    func getTorrent(id: String, completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ())
    func getTorrents(completionHandler: @escaping (Result<[RemoteTorrent], ServerCommunicationError>) -> ())
    
    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent, completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ())
}

protocol HasSpeedLimitSupport {
    
    func getSpeedLimitConfiguration(completionHandler: @escaping (Result<(down: Double, up: Double), ServerCommunicationError>) -> ())
    func getSpeedLimitState(completionHandler: @escaping (Result<(down: Bool, up: Bool), ServerCommunicationError>) -> ())
    
    func setSpeedLimitState(_ enabled: (down: Bool, up: Bool), completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ())
}
