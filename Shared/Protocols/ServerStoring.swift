//
//  ServerStoring.swift
//  SeedTruck
//

import Foundation
import Security

@MainActor
protocol ServerStoring {

    func servers() throws -> [Server]
    func set(_ server: Server) throws
    func removeServer(id: UUID) throws
}

struct KeychainServerStore: ServerStoring {

    static let shared = KeychainServerStore()

    private let service: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(service: String = "io.edr.seedtruck.servers.v1") {
        self.service = service
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func servers() throws -> [Server] {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return []
        }
        guard status == errSecSuccess else {
            throw ServerStoreError.keychain(status)
        }

        let dataItems: [Data]
        if let values = result as? [Data] {
            dataItems = values
        } else if let value = result as? Data {
            dataItems = [value]
        } else {
            throw ServerStoreError.invalidData
        }

        do {
            return try dataItems.map { try decoder.decode(Server.self, from: $0) }
        } catch {
            throw ServerStoreError.invalidData
        }
    }

    func set(_ server: Server) throws {
        let data: Data
        do {
            data = try encoder.encode(server)
        } catch {
            throw ServerStoreError.invalidData
        }

        let query = baseQuery(for: server.id)
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw ServerStoreError.keychain(updateStatus)
        }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ServerStoreError.keychain(addStatus)
        }
    }

    func removeServer(id: UUID) throws {
        let status = SecItemDelete(baseQuery(for: id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ServerStoreError.keychain(status)
        }
    }

    private func baseQuery(for id: UUID? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: true,
            kSecUseDataProtectionKeychain as String: true
        ]
        if let id {
            query[kSecAttrAccount as String] = id.uuidString
        }
        return query
    }
}

enum ServerStoreError: Error, Equatable, LocalizedError, Sendable {

    case invalidData
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The saved server data is invalid."
        case .keychain(let status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "Keychain operation failed with status \(status)."
        }
    }
}
