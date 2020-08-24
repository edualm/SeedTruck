//
//  SettingsActionHandler.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import CoreData
import Foundation

class SettingsActionHandler: ObservableObject {
    
    @Published var showingDeleteAlert = false
    
    var serverUnderModification: Server?
    
    let managedObjectContext: CoreDataManagedObjectDeleter
    
    enum Action {
        
        case abortDeletion
        case delete(Server)
        case confirmDeletion
    }
    
    init(managedObjectContext: CoreDataManagedObjectDeleter) {
        self.managedObjectContext = managedObjectContext
    }
    
    func perform(_ action: Action) {
        switch action {
        case .abortDeletion:
            serverUnderModification = nil
            showingDeleteAlert = false
            
        case .delete(let server):
            serverUnderModification = server
            showingDeleteAlert = true
            
        case .confirmDeletion:
            guard let server = serverUnderModification else {
                assertionFailure("`serverUnderModification` must not be `nil` here!")
                
                return
            }
            
            managedObjectContext.delete(server)
            try! managedObjectContext.save()
            
            serverUnderModification = nil
            showingDeleteAlert = false
        }
    }
}
