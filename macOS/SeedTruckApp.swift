//
//  SeedTruckApp.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 06/09/2020.
//

import SwiftUI

struct ImportCommandActions {

    let openTorrentFile: () -> Void
    let openMagnetLink: () -> Void
}

private struct ImportCommandActionsKey: FocusedValueKey {

    typealias Value = ImportCommandActions
}

struct TorrentCommandActions {

    let canStart: Bool
    let canPause: Bool
    let start: () -> Void
    let pause: () -> Void
}

private struct TorrentCommandActionsKey: FocusedValueKey {

    typealias Value = TorrentCommandActions
}

extension FocusedValues {

    var importCommandActions: ImportCommandActions? {
        get { self[ImportCommandActionsKey.self] }
        set { self[ImportCommandActionsKey.self] = newValue }
    }

    var torrentCommandActions: TorrentCommandActions? {
        get { self[TorrentCommandActionsKey.self] }
        set { self[TorrentCommandActionsKey.self] = newValue }
    }
}

private struct FileCommands: Commands {

    @FocusedValue(\.importCommandActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open Torrent File...") {
                actions?.openTorrentFile()
            }
            .keyboardShortcut("o")
            .disabled(actions == nil)

            Button("Open Magnet Link...") {
                actions?.openMagnetLink()
            }
            .keyboardShortcut("u")
            .disabled(actions == nil)
        }
    }
}

private struct TorrentCommands: Commands {

    @FocusedValue(\.torrentCommandActions) private var actions

    var body: some Commands {
        CommandMenu("Torrent") {
            Button("Start") {
                actions?.start()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(actions?.canStart != true)

            Button("Pause") {
                actions?.pause()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(actions?.canPause != true)
        }
    }
}

@main struct SeedTruckApp: App {

    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage(Constants.StorageKeys.appIcon) private var appIcon = AppIconOption.default
    @StateObject private var serverRepository = ServerRepository()
    
    @SceneBuilder
    var body: some Scene {
        //
        //  Main Window
        //
        
        Window("SeedTruck", id: "main") {
            MainView()
                .frame(minWidth: 700)
                .serverStoreErrorAlert()
                .environmentObject(serverRepository)
                .onAppear {
                    appIcon.applyToDock()
                    serverRepository.refresh()
                }
        }
        .defaultSize(width: 850, height: 600)
        .commands {
            FileCommands()
            TorrentCommands()
            CommandGroup(replacing: .help) {
                Link("Help Center", destination: SeedTruckSupportLinks.helpCenterURL)
                Link(
                    "Submit a Support Request",
                    destination: SeedTruckSupportLinks.supportTicketURL(
                        platformIdentifier: SeedTruckSupportLinks.currentPlatformIdentifier
                    )
                )
                Link("Privacy Policy", destination: SeedTruckSupportLinks.privacyPolicyURL)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                serverRepository.refresh()
            }
        }
        
        //
        //  Settings
        //
        
        Settings {
            SettingsView()
                .serverStoreErrorAlert()
                .environmentObject(serverRepository)
                .onAppear {
                    serverRepository.refresh()
                }
        }
    }
}
