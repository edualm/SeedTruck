//
//  Server+CoreData.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import CoreData
import Foundation

extension Server {
    
    public class func fetchRequest() -> NSFetchRequest<Server> {
        return NSFetchRequest<Server>(entityName: "Server")
    }
    
    public class func new(withManagedContext managedContext: NSManagedObjectContext) -> Server {
        let entity = NSEntityDescription.entity(forEntityName: "Server", in: managedContext)!
                
        let server = NSManagedObject(entity: entity, insertInto: managedContext)
        
        return server as! Server
    }
    
    class func get(withManagedContext managedContext: NSManagedObjectContext) -> [Server] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Server")
        
        return (try? managedContext.fetch(fetchRequest) as? [Server]) ?? []
    }
}
