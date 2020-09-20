//
//  BinaryInteger+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 20/09/2020.
//

import Foundation

extension BinaryInteger {
    
    var humanReadableDate: String? {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.year, .month, .day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        
        return formatter.string(from: Double(self))
    }
}
