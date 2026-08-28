//
//  TorrentClientRegistry.swift
//  SeedTruck
//

import Foundation

struct TorrentClientEndpointMetadata: Sendable {

    enum Kind: Sendable {
        case requestURL
        case baseURL
    }

    let kind: Kind
    let example: String
    let help: String

    func validationError(for endpoint: URL) -> String? {
        guard endpoint.user == nil, endpoint.password == nil else {
            return "Enter credentials in the authentication fields, not in the endpoint URL."
        }
        guard endpoint.query == nil, endpoint.fragment == nil else {
            return "The server endpoint cannot contain a query or fragment."
        }

        if kind == .baseURL,
           endpoint.path.lowercased().contains("/api/v2") {
            return "Enter the qBittorrent Web UI base URL without an API path."
        }
        return nil
    }
}

struct TorrentClientDescriptor: Identifiable, Sendable {

    let id: ServerType
    let displayName: String
    let endpoint: TorrentClientEndpointMetadata
    let authenticationHelp: String
    private let builder: @Sendable (ConnectionDetails) -> any ServerConnection

    init(
        id: ServerType,
        displayName: String,
        endpoint: TorrentClientEndpointMetadata,
        authenticationHelp: String,
        builder: @escaping @Sendable (ConnectionDetails) -> any ServerConnection
    ) {
        self.id = id
        self.displayName = displayName
        self.endpoint = endpoint
        self.authenticationHelp = authenticationHelp
        self.builder = builder
    }

    func makeConnection(for details: ConnectionDetails) -> any ServerConnection {
        builder(details)
    }
}

protocol ServerConnectionBuilding: Sendable {

    func makeConnection(for details: ConnectionDetails) -> any ServerConnection
}

struct TorrentClientRegistry: ServerConnectionBuilding, Sendable {

    static let live = TorrentClientRegistry(descriptors: [
        TorrentClientDescriptor(
            id: .transmission,
            displayName: "Transmission",
            endpoint: .init(
                kind: .requestURL,
                example: "http://server.local:9091/transmission/rpc",
                help: "Enter the full Transmission JSON-RPC URL."
            ),
            authenticationHelp: "Leave both fields empty when Transmission does not require authentication.",
            builder: { TransmissionConnection(connectionDetails: $0) }
        ),
        TorrentClientDescriptor(
            id: .qBittorrent,
            displayName: "qBittorrent",
            endpoint: .init(
                kind: .baseURL,
                example: "http://server.local:8080",
                help: "Enter the qBittorrent Web UI base URL. Reverse-proxy paths are supported."
            ),
            authenticationHelp: "Enter the qBittorrent Web UI username and password, or leave both empty when authentication bypass is configured.",
            builder: { QBittorrentConnection(connectionDetails: $0) }
        )
    ])

    let descriptors: [TorrentClientDescriptor]
    private let descriptorsByID: [ServerType: TorrentClientDescriptor]

    init(descriptors: [TorrentClientDescriptor]) {
        let descriptorsByID = Dictionary(grouping: descriptors, by: \.id)
        precondition(
            descriptorsByID.values.allSatisfy { $0.count == 1 },
            "Torrent client identifiers must be unique."
        )
        self.descriptors = descriptors
        self.descriptorsByID = descriptorsByID.mapValues { $0[0] }
    }

    func descriptor(for type: ServerType) -> TorrentClientDescriptor? {
        descriptorsByID[type]
    }

    func makeConnection(for details: ConnectionDetails) -> any ServerConnection {
        guard let descriptor = descriptor(for: details.type) else {
            return UnavailableServerConnection(
                error: .unsupportedServerType(details.type.code)
            )
        }
        return descriptor.makeConnection(for: details)
    }
}
