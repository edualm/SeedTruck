//
//  Server.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation

struct Server: Codable, Hashable, Identifiable, Sendable {

    let id: UUID
    let endpoint: URL
    let name: String
    let type: Int16
    let credentials: ConnectionDetails.Credentials?
    let customHeaders: [ConnectionDetails.CustomHeader]

    init(
        id: UUID = UUID(),
        endpoint: URL,
        name: String,
        type: Int16,
        credentials: ConnectionDetails.Credentials? = nil,
        customHeaders: [ConnectionDetails.CustomHeader] = []
    ) {
        self.id = id
        self.endpoint = endpoint
        self.name = name
        self.type = type
        self.credentials = credentials
        self.customHeaders = customHeaders
    }

    init(id: UUID = UUID(), draft: TemporaryServer) {
        self.init(
            id: id,
            endpoint: draft.endpoint,
            name: draft.name,
            type: draft.type.rawValue,
            credentials: draft.credentials,
            customHeaders: draft.customHeaders
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case endpoint
        case name
        case type
        case credentials
        case customHeaders
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        endpoint = try container.decode(URL.self, forKey: .endpoint)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(Int16.self, forKey: .type)
        credentials = try container.decodeIfPresent(
            ConnectionDetails.Credentials.self,
            forKey: .credentials
        )
        customHeaders = try container.decodeIfPresent(
            [ConnectionDetails.CustomHeader].self,
            forKey: .customHeaders
        ) ?? []
    }

    var displayHost: String {
        guard let host = endpoint.host else {
            return "Unknown host"
        }

        if let port = endpoint.port {
            return "\(host):\(port)"
        }

        return host
    }

    var connectionDetails: ConnectionDetails {
        ConnectionDetails(
            type: ServerType(rawValue: type),
            endpoint: endpoint,
            credentials: credentials,
            customHeaders: customHeaders
        )
    }

    @MainActor
    var connection: ServerConnection {
        ServerConnectionStore.shared.connection(for: id, details: connectionDetails)
    }

    static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.id == rhs.id
            && lhs.endpoint == rhs.endpoint
            && lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.credentials == rhs.credentials
            && lhs.customHeaders == rhs.customHeaders
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
