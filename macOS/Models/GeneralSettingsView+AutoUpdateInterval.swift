//
//  GeneralSettingsView+AutoUpdateInterval.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 13/12/2020.
//

import Foundation

extension GeneralSettingsView {
    
    enum AutoUpdateInterval: Int, CaseIterable, Hashable {
        
        case twoSeconds
        case fiveSeconds
        case tenSeconds
        case thirtySeconds
        case oneMinute
        case twoMinutes
        case fiveMinutes
        case never
        
        init(seconds: Int) {
            switch seconds {
            case 2:
                self = .twoSeconds
            case 5:
                self = .fiveSeconds
            case 10:
                self = .tenSeconds
            case 30:
                self = .thirtySeconds
            case (1 * 60):
                self = .oneMinute
            case (2 * 60):
                self = .twoMinutes
            case (5 * 60):
                self = .fiveSeconds
            default:
                self = .never
            }
        }
        
        var userFacingString: String {
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
            case .never:
                return "Never (manually)"
            }
        }
        
        var secondsValue: Int {
            switch self {
            case .twoSeconds:
                return 2
            case .fiveSeconds:
                return 5
            case .tenSeconds:
                return 10
            case .thirtySeconds:
                return 30
            case .oneMinute:
                return (1 * 60)
            case .twoMinutes:
                return (2 * 60)
            case .fiveMinutes:
                return (5 * 60)
            case .never:
                return -1
            }
        }
    }
}
