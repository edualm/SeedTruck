//
//  TransmissionConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

struct TransmissionConnection: SeedboxConnection {
    
    struct ConnectionDetails {
        
        struct Credentials {
            
            let username: String
            let password: String
        }
        
        let endpoint: URL
        let credentials: Credentials?
    }
    
    let connectionDetails: ConnectionDetails
    
    init(connectionDetails: ConnectionDetails) {
        self.connectionDetails = connectionDetails
    }
    
    func addTorrent(_ torrent: LocalTorrent) -> Result<RemoteTorrent, SeedboxCommunicationError> {
        return .failure(.notImplemented)
    }
    
    func getTorrents() -> Result<[RemoteTorrent], SeedboxCommunicationError> {
        return .failure(.notImplemented)
    }
    
    func removeTorrent(_ torrent: RemoteTorrent) -> Result<Bool, SeedboxCommunicationError> {
        return .failure(.notImplemented)
    }
    
    func removeTorrent(byId id: String) -> Result<Bool, SeedboxCommunicationError> {
        return .failure(.notImplemented)
    }
}
