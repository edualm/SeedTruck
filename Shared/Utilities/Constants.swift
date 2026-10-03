//
//  Constants.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 13/12/2020.
//

import Foundation

enum Constants {
    
    enum StorageKeys {
        
        static let appIcon = "appIcon"
        static let autoUpdateInterval = "autoUpdateInterval"
        static let torrentSort = "torrentSort"
        static let torrentSortDirection = "torrentSortDirection"
    }
}

enum SeedTruckSupportLinks {

    static let helpCenterURL = URL(
        string: "https://support.bittenapps.com/hc/en-us/sections/38450059271442-Seed-Truck"
    )!
    static let privacyPolicyURL = URL(
        string: "https://bittenapps.com/privacy_policy/seedtruck"
    )!

    static var currentPlatformIdentifier: String {
        #if os(macOS)
        "macos"
        #else
        "ios"
        #endif
    }

    static func supportTicketURL(platformIdentifier: String) -> URL {
        var components = URLComponents(
            string: "https://support.bittenapps.com/hc/en-us/requests/new"
        )!
        components.queryItems = [
            URLQueryItem(name: "tf_360020061259", value: "seed_truck"),
            URLQueryItem(name: "tf_360019930300", value: platformIdentifier)
        ]
        return components.url!
    }
}

enum PollingInterval {

    static func timeInterval(for refreshInterval: Int) -> TimeInterval? {
        guard refreshInterval > 0 else {
            return nil
        }

        return TimeInterval(refreshInterval)
    }
}

enum RefreshIntervalOption: Int, CaseIterable, Identifiable, Sendable {

    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case manualOnly = -1

    var id: Int {
        rawValue
    }

    init(storedValue: Int) {
        if let option = Self(rawValue: storedValue) {
            self = option
        } else {
            self = storedValue <= 0 ? .manualOnly : .twoSeconds
        }
    }

    var label: String {
        switch self {
        case .twoSeconds:
            return "2 seconds"
        case .fiveSeconds:
            return "5 seconds"
        case .tenSeconds:
            return "10 seconds"
        case .thirtySeconds:
            return "30 seconds"
        case .oneMinute:
            return "1 minute"
        case .twoMinutes:
            return "2 minutes"
        case .fiveMinutes:
            return "5 minutes"
        case .manualOnly:
            return "Manual only"
        }
    }
}

enum AppIconOption: String, CaseIterable, Identifiable, Sendable {

    case `default`
    case classic

    var id: String {
        rawValue
    }

    init(alternateIconName: String?) {
        self = Self.allCases.first { $0.alternateIconName == alternateIconName } ?? .default
    }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .classic:
            return "Classic"
        }
    }

    /// The name of the alternate icon in the asset catalog, or `nil` for the primary icon.
    var alternateIconName: String? {
        switch self {
        case .default:
            return nil
        case .classic:
            return "AppIconLegacy"
        }
    }

    var iconName: String {
        alternateIconName ?? "AppIcon"
    }

    var previewImageName: String {
        iconName + "Preview"
    }
}

enum SettingsArea: String, CaseIterable, Identifiable, Sendable {

    case general
    case servers
    case help

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .servers:
            return "server.rack"
        case .help:
            return "questionmark.circle"
        }
    }

    var summary: String {
        switch self {
        case .general:
            return "Refresh interval and app icon"
        case .servers:
            return "Connections, authentication, and limits"
        case .help:
            return "Help Center, support, and privacy"
        }
    }
}
