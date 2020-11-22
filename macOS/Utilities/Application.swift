//
//  Application.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 22/11/2020.
//

import AppKit

enum Application {
    
    static func closeMainWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.keyWindow else {
                assertionFailure("Tried to close the main window without any key window!")
                
                return
            }
            
            window.close()
        }
    }
}
