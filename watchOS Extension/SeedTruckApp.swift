//
//  SeedTruckApp.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import CoreData
import SwiftUI

@main
struct SeedTruckApp: App {
    
    @State private var dataTransferManager: DataTransferManager? = nil
    
    @StateObject private var sharedBucket: SharedBucket = SharedBucket()
    
    private let persistentContainer: NSPersistentContainer = .default
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(sharedBucket)
                .onAppear {
                    if dataTransferManager == nil {
                        dataTransferManager = DataTransferManager(managedObjectContext: persistentContainer.viewContext)
                    }
                }
        }
    }
}
