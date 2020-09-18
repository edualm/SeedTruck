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
    
    static func humanReadableFileSize(bytes: Int64) -> String {
        guard bytes != 0 else {
            return "0 KB"
        }
        
        return formatter.string(fromByteCount: bytes)
    }
    
    static func humanReadableTransmissionSpeed(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "0 KB/s"
        }
        
        return humanReadableFileSize(bytes: Int64(bytesPerSecond)) + "/s"
    }
}
