//
//  AppIconOption+Dock.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 03/10/2026.
//

import AppKit

extension AppIconOption {

    var image: NSImage? {
        NSImage(named: iconName)
    }

    /// macOS has no alternate app icon API, so the icon can only be replaced in the Dock while the app is running.
    @MainActor
    func applyToDock() {
        NSApplication.shared.applicationIconImage = alternateIconName.flatMap { NSImage(named: $0) }
    }
}
