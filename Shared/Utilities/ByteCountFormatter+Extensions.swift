//
//  ByteCountFormatter+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

extension ByteCountFormatter {

    private static func formattedByteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary

        return formatter.string(fromByteCount: bytes)
    }
    
    static func humanReadableFileSize(bytes: Int64) -> String {
        guard bytes != 0 else {
            return "0 KB"
        }
        
        return formattedByteCount(bytes)
    }
    
    static func humanReadableTransferRate(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "0 KB/s"
        }
        
        return humanReadableFileSize(bytes: Int64(bytesPerSecond)) + "/s"
    }

    static func humanReadableCompactTransferRate(bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else {
            return "0"
        }

        let byteCount = Int64(bytesPerSecond)
        let units: [(threshold: Int64, suffix: String)] = [
            (Int64(1) << 50, "P"),
            (Int64(1) << 40, "T"),
            (Int64(1) << 30, "G"),
            (Int64(1) << 20, "M"),
            (Int64(1) << 10, "K"),
            (Int64(1), "B")
        ]
        let unit = units.first { byteCount >= $0.threshold } ?? units[units.count - 1]
        let value = Double(byteCount) / Double(unit.threshold)
        let includesFraction = value < 10 && value.rounded() != value
        let format = includesFraction ? "%.1f%@" : "%.0f%@"

        return String(format: format, value, unit.suffix)
    }
}
