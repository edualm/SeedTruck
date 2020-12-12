//
//  SeedTruckApp.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 06/09/2020.
//

//  TODO: Missing URL handler.

import CoreData
import SwiftUI

@main struct SeedTruckApp: App {
    
    private let persistentContainer: NSPersistentContainer = .default
    
    @State private var openedTorrent: LocalTorrent? = nil
    
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var sharedBucket: SharedBucket = SharedBucket()
    
    @SceneBuilder
    var body: some Scene {
        //
        //  Main Window
        //
        
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(sharedBucket)
                .frame(minWidth: 700)
        }.onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                persistentContainer.save()
                
            default:
                ()
            }
        }
        
        //
        //  Magnet Link Handler
        //
        
        WindowGroup {
            Group {
                if let torrent = openedTorrent {
                    TorrentHandlerNavigationView(torrent: torrent, server: nil)
                        .frame(minWidth: 400)
                } else {
                    EmptyView()
                }
            }
            .environment(\.managedObjectContext, persistentContainer.viewContext)
            .onOpenURL { url in
                openedTorrent = LocalTorrent(url: url)
            }
        }.handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        
        //
        //  Torrent File Handler
        //
        
        DocumentGroup(viewing: TorrentFile.self) {
            TorrentHandlerNavigationView(torrent: $0.document.localTorrent,
                                         server: nil)
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
        
        //
        //  Settings
        //
        
        Settings {
            SettingsView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
        }
    }
}

