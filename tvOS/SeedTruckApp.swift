//
//  SeedTruckApp.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import CoreData
import SwiftUI

@main
struct SeedTruckApp: App {
    
    @StateObject private var sharedBucket: SharedBucket = SharedBucket()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, NSPersistentContainer.default.viewContext)
                .environmentObject(sharedBucket)
        }
    }
}
