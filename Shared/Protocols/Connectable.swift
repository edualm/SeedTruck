//
//  Connectable.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/09/2020.
//

import Foundation

@MainActor
final class ServerConnectionStore {

    static let shared = ServerConnectionStore(builder: TorrentClientRegistry.live)

    private struct Entry {

        let details: ConnectionDetails
        let connection: ServerConnection
    }

    private var entries: [UUID: Entry] = [:]
    private let builder: any ServerConnectionBuilding

    init(builder: any ServerConnectionBuilding) {
        self.builder = builder
    }

    func connection(for serverID: UUID, details: ConnectionDetails) -> ServerConnection {
        if let entry = entries[serverID], entry.details == details {
            return entry.connection
        }

        let connection = builder.makeConnection(for: details)

        entries[serverID] = .init(details: details, connection: connection)

        return connection
    }

    func removeConnection(for serverID: UUID) {
        entries[serverID] = nil
    }
}
