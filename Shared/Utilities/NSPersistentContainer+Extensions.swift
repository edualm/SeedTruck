//
//  NSPersistentContainer+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/11/2020.
//

import CoreData

extension NSPersistentContainer {
    
    static var `default`: NSPersistentContainer {
        let container = NSPersistentContainer(name: "DataModel")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        return container
    }
    
    func save() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
