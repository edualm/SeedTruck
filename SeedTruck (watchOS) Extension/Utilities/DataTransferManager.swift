//
//  DataTransferManager.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import CoreData
import WatchConnectivity

class DataTransferManager: NSObject {
    
    let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        let session = WCSession.default
        session.delegate = self
        
        session.activate()
    }
}

extension DataTransferManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print(activationState)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        
        guard let connectionDataPackage = message["connections"] as? [[String: Any]] else {
            replyHandler(["success": false, "error": "Invalid data received."])
            
            return
        }
        
        try! managedObjectContext.execute(NSBatchDeleteRequest(fetchRequest: Server.fetchRequest()))
        
        connectionDataPackage.forEach {
            _ = Server.new(withManagedContext: managedObjectContext, serializedData: $0)
        }
        
        try! managedObjectContext.save()
        
        replyHandler(["success": true])
    }
}
