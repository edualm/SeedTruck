//
//  Engine.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

class Engine: ObservableObject {
    
    @Published var servers: [Server]
    
    var updateTimer: Timer?
    
    init() {
        self.servers = [
            
        ]
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            self.update()
        }
        
        update()
    }
    
    func update() {
        servers.forEach { server in
            server.connection.getTorrents {
                switch $0 {
                case .success(let torrents):
                    server.torrents = torrents
                    
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                    }
                    
                case .failure:
                    print("Failed to update!")
                }
            }
        }
    }
}
