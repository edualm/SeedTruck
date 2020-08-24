//
//  SeedTruckApp.swift
//  Shared
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI
import CoreData

@main struct SeedTruckApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .onOpenURL { url in
                    if url.isFileURL {
                        //  Handle a `.torrent` file
                    } else {
                        //  Handle a magnet link
                    }
                }
        }.onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                saveContext()
            default:
                ()
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
