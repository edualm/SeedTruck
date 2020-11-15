//
//  SeedTruckApp.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 06/09/2020.
//

import CoreData
import SwiftUI
import UniformTypeIdentifiers

@main struct SeedTruckApp: App {
    
    private static let torrentUTI = "io.edr.seedtruck.torrent"
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var openedTorrent: LocalTorrent? = nil
    
    @StateObject private var sharedBucket: SharedBucket = SharedBucket()
    
    @SceneBuilder
    var body: some Scene {
        let showingURLHandlerSheet = Binding<Bool>(
            get: { openedTorrent != nil },
            set: {
                if !$0 {
                    openedTorrent = nil
                }
            }
        )
        
        WindowGroup {
            MainView()
                .sheet(isPresented: showingURLHandlerSheet) {
                    if let torrent = openedTorrent {
                        #if !os(macOS)
                        URLHandlerView(torrent: torrent)
                        #else
                        EmptyView()
                        #endif
                    } else {
                        EmptyView()
                    }
                }
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(sharedBucket)
                .onOpenURL { url in
                    openedTorrent = LocalTorrent(url: url)
                }
                .onDrop(of: [UTType(exportedAs: Self.torrentUTI)], isTargeted: nil) { providers in
                    guard providers.count == 1 else {
                        return false
                    }
                    
                    let provider = providers[0]
                    
                    provider.loadInPlaceFileRepresentation(forTypeIdentifier: "public.item") { url, success, _ in
                        guard success, let url = url else {
                            return
                        }
                        
                        openedTorrent = LocalTorrent(url: url)
                    }
                    
                    return true
                }
        }.onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                saveContext()
                
            default:
                ()
            }
        }
        
        Settings {
            SettingsContainerView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
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

