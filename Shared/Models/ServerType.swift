//
//  ServerType.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

enum ServerType: String, CaseIterable {
    
    case transmission = "Transmission"
    
    init?(fromCode code: Int) {
        switch code {
        case 0:
            self = .transmission
            
        default:
            return nil
        }
    }
    
    var code: Int {
        switch self {
        case .transmission:
            return 0
        }
    }
}
