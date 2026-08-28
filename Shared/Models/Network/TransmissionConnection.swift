//
//  TransmissionConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

final class TransmissionConnection: ServerConnection, @unchecked Sendable {

    private enum Header: String {

        case authorization = "Authorization"
        case csrfToken = "X-Transmission-Session-Id"
        case contentType = "Content-Type"
    }

    private enum Method: String {

        case sessionGet = "session_get"
        case sessionSet = "session_set"
        case torrentAdd = "torrent_add"
        case torrentGet = "torrent_get"
        case torrentRemove = "torrent_remove"
        case torrentStart = "torrent_start"
        case torrentStop = "torrent_stop"
    }

    static private let torrentFields = ["id", "name", "percent_done", "recheck_progress", "status", "size_when_done", "peers_connected", "rate_upload", "peers_sending_to_us", "peers_getting_from_us", "rate_download", "uploaded_ever", "downloaded_ever", "upload_ratio", "seconds_downloading", "seconds_seeding", "queue_position", "eta", "eta_idle", "labels"]

    private let connectionDetails: ConnectionDetails
    private let session: URLSession
    private let redirectDelegate: CustomHeaderRedirectDelegate
    private let tokenLock = NSLock()
    private var csrfToken: String?

    init(connectionDetails: ConnectionDetails, session: URLSession? = nil) {
        self.connectionDetails = connectionDetails
        redirectDelegate = CustomHeaderRedirectDelegate(connectionDetails: connectionDetails)

        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: configuration)
        }
    }

    private var currentCSRFToken: String? {
        tokenLock.lock()
        defer { tokenLock.unlock() }
        return csrfToken
    }

    private func updateCSRFToken(_ token: String, replacing expectedToken: String?) {
        tokenLock.lock()
        defer { tokenLock.unlock() }

        guard csrfToken == expectedToken else {
            return
        }

        csrfToken = token
    }

    private func makeRequest<Parameters: Encodable>(
        method: Method,
        parameters: Parameters,
        id: String,
        csrfToken: String?
    ) throws -> URLRequest {
        let body = Transmission.RPCRequest(
            method: method.rawValue,
            params: parameters,
            id: id
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        var request = URLRequest(url: connectionDetails.endpoint)
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw ServerCommunicationError.parseError
        }
        request.httpMethod = "POST"
        connectionDetails.applyCustomHeaders(to: &request)
        request.setValue("application/json", forHTTPHeaderField: Header.contentType.rawValue)

        if let credentials = connectionDetails.credentials {
            let rawCredentials = "\(credentials.username):\(credentials.password)"
            guard let encodedCredentials = rawCredentials.data(using: .utf8)?.base64EncodedString() else {
                throw ServerCommunicationError.parseError
            }
            request.setValue("Basic \(encodedCredentials)", forHTTPHeaderField: Header.authorization.rawValue)
        }

        if let csrfToken {
            request.setValue(csrfToken, forHTTPHeaderField: Header.csrfToken.rawValue)
        }

        return request
    }

    private func performCall<Parameters: Encodable, Value: Decodable>(
        method: Method,
        parameters: Parameters
    ) async throws -> Value {
        let requestID = UUID().uuidString

        for attempt in 0...1 {
            try Task.checkCancellation()

            let requestToken = currentCSRFToken
            let request = try makeRequest(
                method: method,
                parameters: parameters,
                id: requestID,
                csrfToken: requestToken
            )
            let data: Data
            let response: URLResponse

            do {
                (data, response) = try await session.data(
                    for: request,
                    delegate: redirectDelegate
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as URLError {
                throw ServerCommunicationError.connectivity(error, endpoint: connectionDetails.endpoint)
            } catch {
                throw ServerCommunicationError.serverError(error.localizedDescription)
            }

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServerCommunicationError.invalidResponse
            }

            if httpResponse.statusCode == 409 {
                guard attempt == 0,
                      let newToken = httpResponse.value(forHTTPHeaderField: Header.csrfToken.rawValue),
                      !newToken.isEmpty else {
                    throw ServerCommunicationError.invalidResponse
                }

                updateCSRFToken(newToken, replacing: requestToken)
                continue
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                throw ServerCommunicationError.httpStatus(httpResponse.statusCode)
            }

            let parsedResponse: Transmission.RPCResponse<Value>

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                parsedResponse = try decoder.decode(Transmission.RPCResponse<Value>.self, from: data)
            } catch {
                throw ServerCommunicationError.parseError
            }

            guard parsedResponse.jsonrpc == "2.0", parsedResponse.id == requestID else {
                throw ServerCommunicationError.invalidResponse
            }

            switch (parsedResponse.result, parsedResponse.error) {
            case let (result?, nil):
                return result
            case let (nil, error?):
                let detail = error.data?.errorString
                let message: String
                if let detail, !detail.isEmpty, detail != error.message {
                    message = "\(error.message): \(detail)"
                } else {
                    message = error.message
                }
                throw ServerCommunicationError.serverError(message)
            default:
                throw ServerCommunicationError.invalidResponse
            }
        }

        throw ServerCommunicationError.invalidResponse
    }

    func checkConnection() async throws {
        _ = try await getTorrents()
    }

    #if os(iOS) || os(macOS)
    func addTorrent(_ request: TorrentAddRequest) async throws {
        let filename: String?
        let metainfo: String?

        switch request.source {
        case .magnet(let magnet):
            filename = magnet
            metainfo = nil
        case .metainfo(let data):
            filename = nil
            metainfo = data.base64EncodedString()
        }

        let parameters = Transmission.TorrentAddParameters(
            filename: filename,
            metainfo: metainfo,
            labels: request.tags.isEmpty ? nil : request.tags
        )

        let response: Transmission.TorrentAddResult = try await performCall(
            method: .torrentAdd,
            parameters: parameters
        )

        guard response.torrentAdded != nil || response.torrentDuplicate != nil else {
            throw ServerCommunicationError.parseError
        }
    }
    #endif

    private func getTorrents(ids: [Int]) async throws -> [RemoteTorrent] {
        let parameters = Transmission.TorrentGetParameters(
            fields: Self.torrentFields,
            ids: ids.isEmpty ? nil : ids
        )

        let response: Transmission.TorrentGetResult = try await performCall(
            method: .torrentGet,
            parameters: parameters
        )

        let torrents = response.torrents.compactMap(RemoteTorrent.init(from:))
        guard torrents.count == response.torrents.count else {
            throw ServerCommunicationError.parseError
        }

        return torrents
    }

    func getTorrent(id: String) async throws -> RemoteTorrent {
        guard let id = Int(id) else {
            throw ServerCommunicationError.parseError
        }

        let torrents = try await getTorrents(ids: [id])
        guard torrents.count == 1, let torrent = torrents.first else {
            throw ServerCommunicationError.parseError
        }

        return torrent
    }

    func getTorrents() async throws -> [RemoteTorrent] {
        try await getTorrents(ids: [])
    }

    private func integerIDs(from ids: [String]) throws -> [Int] {
        let integerIDs = ids.compactMap(Int.init)
        guard integerIDs.count == ids.count else {
            throw ServerCommunicationError.parseError
        }
        return integerIDs
    }

    private func removeTorrents(byID ids: [String], deletingData: Bool) async throws {
        let parameters = Transmission.TorrentRemoveParameters(
            ids: try integerIDs(from: ids),
            deleteLocalData: deletingData
        )

        let _: Transmission.EmptyResult = try await performCall(
            method: .torrentRemove,
            parameters: parameters
        )
    }

    private func performGenericAction(method: Method, torrentIDs: [String]) async throws {
        let parameters = Transmission.TorrentIDsParameters(ids: try integerIDs(from: torrentIDs))
        let _: Transmission.EmptyResult = try await performCall(
            method: method,
            parameters: parameters
        )
    }

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws {
        switch action {
        case .stop:
            try await performGenericAction(method: .torrentStop, torrentIDs: [torrent.id])
        case .remove(let policy):
            try await removeTorrents(
                byID: [torrent.id],
                deletingData: policy == .deleteLocalData
            )
        case .start:
            try await performGenericAction(method: .torrentStart, torrentIDs: [torrent.id])
        }
    }
}

extension TransmissionConnection: GlobalSpeedLimitSupporting {

    func globalSpeedLimits() async throws -> GlobalSpeedLimits {
        let parameters = Transmission.SessionGetParameters(
            fields: [
                "speed_limit_up",
                "speed_limit_down",
                "speed_limit_up_enabled",
                "speed_limit_down_enabled"
            ]
        )
        let response: Transmission.SessionSpeedLimits = try await performCall(
            method: .sessionGet,
            parameters: parameters
        )

        guard let speedLimitDownValue = response.speedLimitDown,
              let speedLimitUpValue = response.speedLimitUp,
              let speedLimitDown = Int64(exactly: speedLimitDownValue),
              let speedLimitUp = Int64(exactly: speedLimitUpValue),
              let speedLimitDownEnabled = response.speedLimitDownEnabled,
              let speedLimitUpEnabled = response.speedLimitUpEnabled,
              speedLimitDown >= 0,
              speedLimitUp >= 0,
              speedLimitDown <= Int64.max / 1_000,
              speedLimitUp <= Int64.max / 1_000 else {
            throw ServerCommunicationError.parseError
        }

        return GlobalSpeedLimits(
            download: .init(
                bytesPerSecond: speedLimitDown * 1_000,
                isEnabled: speedLimitDownEnabled
            ),
            upload: .init(
                bytesPerSecond: speedLimitUp * 1_000,
                isEnabled: speedLimitUpEnabled
            )
        )
    }

    func setGlobalSpeedLimits(_ limits: GlobalSpeedLimits) async throws {
        let downloadKilobytes = limits.download.bytesPerSecond / 1_000
        let uploadKilobytes = limits.upload.bytesPerSecond / 1_000
        guard let downloadKilobytes = Int(exactly: downloadKilobytes),
              let uploadKilobytes = Int(exactly: uploadKilobytes) else {
            throw ServerCommunicationError.parseError
        }

        let parameters = Transmission.SessionSetParameters(
            speedLimitDown: downloadKilobytes,
            speedLimitDownEnabled: limits.download.isEnabled,
            speedLimitUp: uploadKilobytes,
            speedLimitUpEnabled: limits.upload.isEnabled
        )
        let _: Transmission.EmptyResult = try await performCall(
            method: .sessionSet,
            parameters: parameters
        )
    }
}

extension TransmissionConnection: TorrentTagProviding {

    func availableTags() async throws -> [String] {
        Array(Set(try await getTorrents().flatMap(\.labels))).sorted()
    }
}
