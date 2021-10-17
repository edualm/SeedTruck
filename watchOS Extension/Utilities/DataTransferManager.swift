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
        //  Do nothing.
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        self.session(session, didReceiveMessage: message) { _ in }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let connectionDataPackage = message["connections"] as? [[String: Any]] else {
            replyHandler(["success": false, "error": "Invalid data received."])
            
            return
        }
        
        do {
            let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: Server.fetchRequest())
            batchDeleteRequest.resultType = .resultTypeObjectIDs
            
            let deletionResult = try managedObjectContext.execute(batchDeleteRequest) as! NSBatchDeleteResult
            
            let changes: [AnyHashable: Any] = [
                NSDeletedObjectsKey: deletionResult.result as! [NSManagedObjectID]
            ]
            
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [managedObjectContext])
            
            connectionDataPackage.forEach {
                let server = Server.new(withManagedContext: managedObjectContext, serializedData: $0)
                
                managedObjectContext.insert(server)
            }
            
            try managedObjectContext.save()
        } catch {
            print(error)
        }
    }
}
