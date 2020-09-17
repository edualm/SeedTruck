//
//  Connectable.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/09/2020.
//

protocol Connectable {
    
    var connectionDetails: ConnectionDetails { get }
}

extension Connectable {
    
    var connection: ServerConnection {
        switch connectionDetails.type {
        case .transmission:
            let credentials: TransmissionConnection.ConnectionDetails.Credentials?
            
            if let c = connectionDetails.credentials {
                credentials = TransmissionConnection.ConnectionDetails.Credentials(username: c.username, password: c.password)
            } else {
                credentials = nil
            }
            
            return TransmissionConnection(connectionDetails: .init(endpoint: connectionDetails.endpoint, credentials: credentials))
        }
    }
}
