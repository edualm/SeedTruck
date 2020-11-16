//
//  SeedTruckApp.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 06/09/2020.
//

import CoreData
import SwiftUI

@main struct SeedTruckApp: App {
    
    private let persistentContainer: NSPersistentContainer = .default
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var openedTorrent: LocalTorrent? = nil
    
    @StateObject private var sharedBucket: SharedBucket = SharedBucket()
    
    @SceneBuilder
    var body: some Scene {        
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(sharedBucket)
                .onOpenURL { url in
                    openedTorrent = LocalTorrent(url: url)
                }
                .onDrop(of: [UTI.torrent], isTargeted: nil) { providers in
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
                persistentContainer.save()
                
            default:
                ()
            }
        }
        
        DocumentGroup(viewing: TorrentFile.self) {
            TorrentHandlerNavigationView(torrent: $0.document.localTorrent,
                                         server: nil)
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
        
        Settings {
            SettingsContainerView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
    }
}

