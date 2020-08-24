//
//  Server.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

class Server: ObservableObject {
    
    struct ConnectionDetails {
        
        let type: ServerType
        let endpoint: URL
        let credentials: URLCredential?
    }
    
    let id: UUID
    let name: String
    
    let connectionDetails: ConnectionDetails
    
    @Published var torrents: [RemoteTorrent]
    
    init(id: UUID = UUID(), name: String, connectionDetails: ConnectionDetails, torrents: [RemoteTorrent] = []) {
        self.id = id
        self.name = name
        self.connectionDetails = connectionDetails
        self.torrents = torrents
    }
    
    lazy var connection: ServerConnection = {
        switch connectionDetails.type {
        case .transmission:
            let credentials: TransmissionConnection.ConnectionDetails.Credentials?
            
            if let c = connectionDetails.credentials, let username = c.user, let password = c.password {
                credentials = TransmissionConnection.ConnectionDetails.Credentials(username: username, password: password)
            } else {
                credentials = nil
            }
            
            return TransmissionConnection(connectionDetails: .init(endpoint: connectionDetails.endpoint, credentials: credentials))
        }
    }()
}

extension Server: Equatable {
    
    static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.id == rhs.id
    }
}

extension Server: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
