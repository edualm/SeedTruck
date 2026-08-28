//
//  SeedboxConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum ConnectivityFailure: Equatable, Sendable {

    case localNetworkUnavailable
    case localNetworkTimedOut
    case offline
    case connectionLost
    case hostNotFound
    case connectionRefused
    case timedOut
    case secureConnectionFailed
    case other(code: Int, message: String)
}

extension RemoteTorrent {

    enum RemovalPolicy: Equatable, Hashable, Sendable {
        case keepLocalData
        case deleteLocalData
    }
    
    enum Action: Equatable, Hashable, Sendable {
        case stop
        case remove(RemovalPolicy)
        case start
    }
}

enum ServerCommunicationError: Error, Equatable, LocalizedError, Sendable {
    
    case notImplemented
    case notSupported
    case parseError
    case invalidResponse
    case httpStatus(Int)
    case serverError(String?)
    case unsupportedServerType(Int)
    case unsupportedServerVersion(String)
    case authenticationFailed
    case connectivity(ConnectivityFailure)

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "The requested operation is not implemented."
        case .notSupported:
            return "The server does not support the requested operation."
        case .parseError:
            return "The server response could not be parsed."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpStatus(let statusCode):
            return "The server returned HTTP status \(statusCode)."
        case .serverError(let message):
            return message ?? "The server returned an error."
        case .unsupportedServerType(let code):
            return "Server type \(code) is not supported by this version of Seed Truck."
        case .unsupportedServerVersion(let version):
            return "Server version \(version) is not supported."
        case .authenticationFailed:
            return "The server rejected the configured credentials."
        case .connectivity(.localNetworkUnavailable):
            #if os(iOS)
            return "Seed Truck could not reach this local server. Confirm it is online and allow Local Network access in Settings, then retry."
            #elseif os(macOS)
            if #available(macOS 15, *) {
                return "Seed Truck could not reach this local server. Confirm it is online and allow Local Network access in System Settings, then retry."
            }
            return "Seed Truck could not reach this local server. Confirm the Mac and server are on the same network, then retry."
            #else
            return "Seed Truck could not reach this local server. Confirm the device and server are on the same network, then retry."
            #endif
        case .connectivity(.localNetworkTimedOut):
            #if os(iOS)
            return "The local server connection timed out. Confirm the server is online and Local Network access is allowed in Settings, then retry."
            #elseif os(macOS)
            if #available(macOS 15, *) {
                return "The local server connection timed out. Confirm the server is online and Local Network access is allowed in System Settings, then retry."
            }
            return "The local server connection timed out. Confirm the Mac and server are on the same network, then retry."
            #else
            return "The local server connection timed out. Confirm the device and server are on the same network, then retry."
            #endif
        case .connectivity(.offline):
            return "The device appears to be offline. Check the network connection and retry."
        case .connectivity(.connectionLost):
            return "The connection to the server was interrupted. Retry the request."
        case .connectivity(.hostNotFound):
            return "The server address could not be resolved. Check the endpoint and retry."
        case .connectivity(.connectionRefused):
            return "The server refused the connection. Confirm the torrent client is running and the endpoint is correct."
        case .connectivity(.timedOut):
            return "The connection timed out. Check the server and retry."
        case .connectivity(.secureConnectionFailed):
            return "A secure connection could not be established. Check the server certificate and endpoint."
        case .connectivity(.other(_, let message)):
            return message
        }
    }

    var suggestsLocalNetworkRecovery: Bool {
        switch self {
        case .connectivity(.localNetworkUnavailable), .connectivity(.localNetworkTimedOut):
            #if os(iOS)
            return true
            #elseif os(macOS)
            if #available(macOS 15, *) {
                return true
            }
            #endif
        default:
            break
        }
        return false
    }

    static func connectivity(_ error: URLError, endpoint: URL) -> ServerCommunicationError {
        if endpoint.isLocalNetworkEndpoint, error.code == .notConnectedToInternet {
            return .connectivity(.localNetworkUnavailable)
        }
        if endpoint.isLocalNetworkEndpoint, error.code == .timedOut {
            return .connectivity(.localNetworkTimedOut)
        }

        switch error.code {
        case .notConnectedToInternet:
            return .connectivity(.offline)
        case .networkConnectionLost:
            return .connectivity(.connectionLost)
        case .cannotFindHost, .dnsLookupFailed:
            return .connectivity(.hostNotFound)
        case .cannotConnectToHost:
            return .connectivity(.connectionRefused)
        case .timedOut:
            return .connectivity(.timedOut)
        case .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .clientCertificateRejected,
             .clientCertificateRequired:
            return .connectivity(.secureConnectionFailed)
        default:
            return .connectivity(.other(code: error.errorCode, message: error.localizedDescription))
        }
    }
}

extension URL {

    var isLocalNetworkEndpoint: Bool {
        guard var host = host?.lowercased() else {
            return false
        }
        if host.hasSuffix(".") {
            host.removeLast()
        }
        if host == "localhost"
            || host.hasSuffix(".local")
            || host.hasSuffix(".lan")
            || host.hasSuffix(".home.arpa")
            || host == "::1" {
            return true
        }
        if host.contains(":"),
           let firstHextet = host.split(separator: ":", omittingEmptySubsequences: false).first,
           let prefix = UInt16(firstHextet, radix: 16) {
            if prefix & 0xffc0 == 0xfe80 || prefix & 0xfe00 == 0xfc00 {
                return true
            }
        }
        if !host.contains(".") && !host.contains(":") {
            return true
        }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count == 4 else {
            return false
        }
        var octets: [UInt8] = []
        for label in labels {
            guard let octet = UInt8(label) else {
                return false
            }
            octets.append(octet)
        }
        return octets[0] == 10
            || octets[0] == 127
            || (octets[0] == 169 && octets[1] == 254)
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }
}

protocol ServerConnection: Sendable {

    func checkConnection() async throws

    #if os(iOS) || os(macOS)
    func addTorrent(_ request: TorrentAddRequest) async throws
    #endif

    func getTorrent(id: String) async throws -> RemoteTorrent
    func getTorrents() async throws -> [RemoteTorrent]

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws
}

struct TransferRateLimit: Equatable, Sendable {

    var bytesPerSecond: Int64
    var isEnabled: Bool
}

struct GlobalSpeedLimits: Equatable, Sendable {

    var download: TransferRateLimit
    var upload: TransferRateLimit
}

protocol GlobalSpeedLimitSupporting: Sendable {

    func globalSpeedLimits() async throws -> GlobalSpeedLimits
    func setGlobalSpeedLimits(_ limits: GlobalSpeedLimits) async throws
}

protocol TorrentTagProviding: Sendable {

    func availableTags() async throws -> [String]
}

#if os(iOS) || os(macOS)
struct TorrentAddRequest: Sendable {

    enum Source: Sendable {
        case magnet(String)
        case metainfo(Data)
    }

    let source: Source
    let tags: [String]

    init(torrent: LocalTorrent, tags: [String]? = nil) {
        switch torrent {
        case .magnet(let magnet, _):
            source = .magnet(magnet)
        case .torrent(let data, _, _):
            source = .metainfo(data)
        }

        self.tags = tags ?? torrent.labels
    }
}
#endif

struct UnavailableServerConnection: ServerConnection {

    let error: ServerCommunicationError

    func checkConnection() async throws {
        throw error
    }

    #if os(iOS) || os(macOS)
    func addTorrent(_ request: TorrentAddRequest) async throws {
        throw error
    }
    #endif

    func getTorrent(id: String) async throws -> RemoteTorrent {
        throw error
    }

    func getTorrents() async throws -> [RemoteTorrent] {
        throw error
    }

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws {
        throw error
    }
}
