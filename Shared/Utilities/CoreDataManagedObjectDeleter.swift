//
//  CoreDataManagedObjectDeleter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import CoreData

protocol CoreDataManagedObjectDeleter {
    
    func delete(_ object: NSManagedObject)
}

extension NSManagedObjectContext: CoreDataManagedObjectDeleter {}

class MockCoreDataManagedObjectDeleter: CoreDataManagedObjectDeleter {
    
    func delete(_ object: NSManagedObject) {}
}
