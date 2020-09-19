//
//  MockCoreDataManagedObjectDeleter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 19/09/2020.
//

import CoreData

class MockCoreDataManagedObjectDeleter: CoreDataManagedObjectDeleter {
    
    func delete(_ object: NSManagedObject) {}
    func save() {}
}
