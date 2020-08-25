//
//  SeedTruckApp.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI
import CoreData

@main
struct SeedTruckApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var dataTransferManager: DataTransferManager? = nil
    
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                MainView()
                    .environment(\.managedObjectContext, persistentContainer.viewContext)
                    .onAppear {
                        if dataTransferManager == nil {
                            dataTransferManager = DataTransferManager(managedObjectContext: persistentContainer.viewContext)
                        }
                    }
            }
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
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
