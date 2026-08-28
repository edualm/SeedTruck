//
//  SeedTruckApp.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

@main
struct SeedTruckApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var serverRepository = ServerRepository()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .serverStoreErrorAlert()
                .environmentObject(serverRepository)
                .onAppear {
                    serverRepository.refresh()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                serverRepository.refresh()
            }
        }
    }
}
