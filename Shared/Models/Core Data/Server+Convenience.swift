//
//  Server+Convenience.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

extension Server {
    
    var connection: ServerConnection {
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
    }
}
