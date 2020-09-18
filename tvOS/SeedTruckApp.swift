//
//  SeedTruckApp.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import CoreData
import SwiftUI

@main
struct SeedTruckApp: App {
    
    @StateObject private var sharedBucket: SharedBucket = SharedBucket()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(sharedBucket)
        }
    }
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        return container
    }()
}
