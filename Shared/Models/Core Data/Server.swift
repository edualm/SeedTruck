//
//  ServerConnectionDetails.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation
import CoreData

class Server: NSManagedObject, Identifiable {
    
    struct ConnectionDetails {
        
        let type: ServerType
        let endpoint: URL
        let credentials: URLCredential?
    }
    
    @NSManaged var endpoint: URL
    @NSManaged var name: String
    @NSManaged var type: Int16
    
    @NSManaged var credentialUsername: String?
    @NSManaged var credentialPassword: String?
    
    var connectionDetails: ConnectionDetails {
        let credentials: URLCredential?
        
        if let username = credentialUsername, let password = credentialPassword {
            credentials = URLCredential(user: username, password: password, persistence: .none)
        } else {
            credentials = nil
        }
        
        return ConnectionDetails(type: ServerType(fromCode: Int(type))!,
                                 endpoint: endpoint,
                                 credentials: credentials)
    }
}
