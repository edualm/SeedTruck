//
//  ServerType.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

struct ServerType: Hashable, RawRepresentable, Sendable {

    static let transmission = ServerType(rawValue: 0)
    static let qBittorrent = ServerType(rawValue: 1)

    let rawValue: Int16

    init(rawValue: Int16) {
        self.rawValue = rawValue
    }

    init?(fromCode code: Int) {
        guard let rawValue = Int16(exactly: code) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    var code: Int {
        Int(rawValue)
    }
}
