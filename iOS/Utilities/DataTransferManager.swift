//
//  DataTransferManager.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Combine
import CoreData
import WatchConnectivity

class DataTransferManager: NSObject, DataTransferManageable {
    
    let managedObjectContext: NSManagedObjectContext
    var mocDidChange: AnyCancellable!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        
        super.init()
        
        mocDidChange = NotificationCenter.default
            .publisher(for: .NSManagedObjectContextDidSave)
            .sink(receiveValue: { _ in
                self.sendUpdateToWatch()
            })
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            
            session.activate()
        } else {
            print("WatchConnectivity not supported on this device!")
        }
    }
    
    func sendUpdateToWatch(completionHandler: ((Result<Int, Error>) -> ())? = nil) {
        WCSession.default.sendMessage(["connections": Server.get(withManagedContext: managedObjectContext).map { $0.serialized }], replyHandler: {
            guard let updatedRecords = $0["records"] as? Int else {
                assertionFailure("Received an invalid response from the Apple Watch!")
                
                return
            }
            
            completionHandler?(.success(updatedRecords))
        }, errorHandler: {
            completionHandler?(.failure($0))
        })
    }
}

extension DataTransferManager: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            sendUpdateToWatch()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        
    }
}
