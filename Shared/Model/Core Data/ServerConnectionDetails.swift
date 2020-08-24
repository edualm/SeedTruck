//
//  ServerConnectionDetails.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation
import CoreData

class ServerConnectionDetails: NSManagedObject, Identifiable {
    
    @NSManaged var id: UUID
    @NSManaged var endpoint: URL
    @NSManaged var name: String
    @NSManaged var type: Int
    
    @NSManaged var credentialUsername: String?
    @NSManaged var credentialPassword: String?
}

extension ServerConnectionDetails {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ServerConnectionDetails> {
        return NSFetchRequest<ServerConnectionDetails>(entityName: "ServerConnectionDetails")
    }
}
