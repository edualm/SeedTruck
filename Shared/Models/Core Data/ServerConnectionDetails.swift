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

extension Server {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Server> {
        return NSFetchRequest<Server>(entityName: "Server")
    }
    
    @nonobjc public class func new(withManagedContext managedContext: NSManagedObjectContext) -> Server {
        let entity = NSEntityDescription.entity(forEntityName: "Server", in: managedContext)!
                
        let server = NSManagedObject(entity: entity, insertInto: managedContext)
        
        return server as! Server
    }
    
    @nonobjc var connection: ServerConnection {
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
