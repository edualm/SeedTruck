//
//  SeedTruckApp.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

@main struct SeedTruckApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var openedTorrent: LocalTorrent? = nil
    @State private var importErrorMessage: String?
    @StateObject private var serverRepository = ServerRepository()
    
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
        let showingImportError = Binding<Bool>(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
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
                .serverStoreErrorAlert()
                .environmentObject(serverRepository)
                .alert("Unable to Add Torrent", isPresented: showingImportError) {
                    Button("OK", role: .cancel) {
                        importErrorMessage = nil
                    }
                } message: {
                    Text(importErrorMessage ?? "The torrent could not be imported.")
                }
                .onOpenURL { url in
                    do {
                        openedTorrent = try LocalTorrent(validating: url)
                    } catch {
                        importErrorMessage = error.localizedDescription
                    }
                }
                .onDrop(of: [UTI.torrent], isTargeted: nil) { providers in
                    guard providers.count == 1 else {
                        return false
                    }
                    
                    let provider = providers[0]
                    
                    provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTI.torrent.identifier) { url, _, error in
                        guard let url else {
                            let message = error?.localizedDescription ?? TorrentImportError.unreadableFile.localizedDescription
                            Task { @MainActor in
                                importErrorMessage = message
                            }
                            return
                        }

                        do {
                            let torrent = try LocalTorrent(validating: url)
                            Task { @MainActor in
                                openedTorrent = torrent
                            }
                        } catch {
                            let message = error.localizedDescription
                            Task { @MainActor in
                                importErrorMessage = message
                            }
                        }
                    }
                    
                    return true
                }
                .onAppear {
                    serverRepository.refresh()
                }
                .statusBarHidden(CommandLine.arguments.contains("--hide-status-bar"))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                serverRepository.refresh()
            }
        }
    }
}
