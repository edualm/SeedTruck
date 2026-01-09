//
//  SeedTruckApp.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import CoreData
import SwiftUI

@main struct SeedTruckApp: App {
    
    private let persistentContainer: NSPersistentContainer = .default
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var openedTorrent: LocalTorrent? = nil
    @State private var dataTransferManager: DataTransferManager? = nil
    
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
                        TorrentHandlerNavigationView(torrent: torrent, server: nil)
                    } else {
                        EmptyView()
                    }
                }
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
                .onAppear {
                    if dataTransferManager == nil {
                        dataTransferManager = DataTransferManager(managedObjectContext: persistentContainer.viewContext)
                        
                        sharedBucket.dataTransferManager = dataTransferManager
                    }
                }
        }.onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                persistentContainer.save()
                
            default:
                ()
            }
        }
    }
}
