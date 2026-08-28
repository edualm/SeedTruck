//
//  ServerRepository.swift
//  SeedTruck
//

import Combine
import Foundation

@MainActor
final class ServerRepository: ObservableObject {

    @Published private(set) var servers: [Server]
    @Published var errorMessage: String?

    private let store: any ServerStoring

    init(
        store: any ServerStoring = KeychainServerStore.shared,
        initialServers: [Server] = []
    ) {
        self.store = store
        servers = Self.sorted(initialServers)
    }

    func refresh() {
        do {
            let updatedServers = Self.sorted(try store.servers())
            let currentServers = Dictionary(uniqueKeysWithValues: servers.map { ($0.id, $0) })
            let updatedIDs = Set(updatedServers.map(\.id))

            for server in servers where !updatedIDs.contains(server.id) {
                ServerConnectionStore.shared.removeConnection(for: server.id)
            }
            for server in updatedServers where currentServers[server.id]?.connectionDetails != server.connectionDetails {
                ServerConnectionStore.shared.removeConnection(for: server.id)
            }

            servers = updatedServers
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func insert(_ draft: TemporaryServer) throws -> Server {
        try ensureUniqueName(draft.name)
        let server = Server(draft: draft)
        try store.set(server)
        servers = Self.sorted(servers + [server])
        return server
    }

    @discardableResult
    func update(id: UUID, with draft: TemporaryServer) throws -> Server {
        guard servers.contains(where: { $0.id == id }) else {
            throw ServerPersistenceError.persistence("The server no longer exists.")
        }
        try ensureUniqueName(draft.name, excluding: id)

        let server = Server(id: id, draft: draft)
        try store.set(server)
        ServerConnectionStore.shared.removeConnection(for: id)
        servers = Self.sorted(servers.map { $0.id == id ? server : $0 })
        return server
    }

    func delete(id: UUID) throws {
        try store.removeServer(id: id)
        ServerConnectionStore.shared.removeConnection(for: id)
        servers.removeAll { $0.id == id }
    }

    func server(id: UUID) -> Server? {
        servers.first { $0.id == id }
    }

    private func ensureUniqueName(_ name: String, excluding excludedID: UUID? = nil) throws {
        guard !servers.contains(where: {
            $0.id != excludedID && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) else {
            throw ServerPersistenceError.duplicateName
        }
    }

    private static func sorted(_ servers: [Server]) -> [Server] {
        servers.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
