//
//  Server+Serialization.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import CoreData
import Foundation

extension Server {
    
    public class func new(withManagedContext managedContext: NSManagedObjectContext, serializedData: [String: Any]) -> Server {
        let newServer = new(withManagedContext: managedContext)
        
        newServer.endpoint = URL(string: serializedData["endpoint"] as! String)!
        newServer.name = serializedData["name"] as! String
        newServer.type = Int16(serializedData["type"] as! Int)
        
        if let username = serializedData["credentialUsername"] as? String, let password = serializedData["credentialPassword"] as? String {
            newServer.credentialUsername = username
            newServer.credentialPassword = password
        }
        
        return newServer
    }
    
    var serialized: [String: Any] {
        var dict: [String: Any] = [
            "endpoint": endpoint.absoluteString,
            "name": name,
            "type": Int(type)
        ]
        
        if let username = credentialUsername, let password = credentialPassword {
            dict["credentialUsername"] = username
            dict["credentialPassword"] = password
        }
        
        return dict
    }
}
