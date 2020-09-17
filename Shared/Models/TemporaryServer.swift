//
//  TemporaryServer.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/09/2020.
//

import CoreData
import Foundation

struct TemporaryServer: Connectable {
    
    let endpoint: URL
    let name: String
    let type: Int16
    
    let credentialUsername: String?
    let credentialPassword: String?
    
    var connectionDetails: ConnectionDetails {
        let credentials: (String, String)?
        
        if let username = credentialUsername, let password = credentialPassword {
            credentials = (username, password)
        } else {
            credentials = nil
        }
        
        return ConnectionDetails(type: ServerType(fromCode: Int(type))!,
                                 endpoint: endpoint,
                                 credentials: credentials)
    }
    
    func convertToServer(withManagedContext managedObjectContext: NSManagedObjectContext) -> Server {
        let newServer = Server.new(withManagedContext: managedObjectContext)
        
        newServer.name = name
        newServer.endpoint = endpoint
        newServer.type = Int16(type)
        
        if let cu = credentialUsername, let cp = credentialPassword {
            newServer.credentialUsername = cu
            newServer.credentialPassword = cp
        }
        
        return newServer
    }
}
