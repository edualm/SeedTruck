//
//  ByteCountFormatter+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

extension ByteCountFormatter {
    
    static private var formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        
        return formatter
    }()
    
    static func humanReadableFileSize(bytes: Int) -> String {
        guard bytes != 0 else {
            return "0 KB"
        }
        
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    static func humanReadableTransmissionSpeed(bytesPerSecond: Int) -> String {
        humanReadableFileSize(bytes: bytesPerSecond) + "/s"
    }
}
