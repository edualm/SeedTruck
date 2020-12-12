//
//  TorrentsView+Shared.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import Foundation

extension TorrentsView {
    
    var filterMenuItems: [MenuItem] {
        [
            menuItem(forFilter: .stopped),
            menuItem(forFilter: .downloading),
            menuItem(forFilter: .seeding),
            menuItem(forFilter: .other)
        ].compactMap { $0 }
    }
    
    func menuItem(forFilter f: Filter) -> MenuItem? {
        switch f {
        case .stopped:
            return .init(name: "Stopped", systemImage: "stop.circle") {
                filter = .stopped
            }
            
        case .downloading:
            return .init(name: "Downloading", systemImage: "arrow.down.forward.circle") {
                filter = .downloading
            }
            
        case .seeding:
            return .init(name: "Seeding", systemImage: "arrow.up.forward.circle") {
                filter = .seeding
            }
            
        case .other:
            return .init(name: "Other", systemImage: "questionmark.circle") {
                filter = .other
            }
        }
    }
    
    func onAppear() {
        if selectedServer == nil {
            selectedServer = serverConnections.first
        }
    }
}
