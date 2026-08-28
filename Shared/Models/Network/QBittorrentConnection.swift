//
//  QBittorrentConnection.swift
//  SeedTruck
//

import Foundation

actor QBittorrentConnection: ServerConnection {

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    private struct Response {
        let data: Data
        let http: HTTPURLResponse
    }

    private let connectionDetails: ConnectionDetails
    private let session: URLSession
    private let redirectDelegate: CustomHeaderRedirectDelegate
    private var sessionID: String?
    private var authenticationTask: Task<String, Error>?
    private var validatedVersion = false
    private var versionTask: Task<Void, Error>?

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
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func checkConnection() async throws {
        try await ensureCompatibleVersion()
    }

    #if os(iOS) || os(macOS)
    func addTorrent(_ request: TorrentAddRequest) async throws {
        let boundary = "SeedTruck-\(UUID().uuidString)"
        var body = Data()

        switch request.source {
        case .magnet(let magnet):
            Self.appendTextPart(name: "urls", value: magnet, boundary: boundary, to: &body)
        case .metainfo(let data):
            Self.appendFilePart(
                name: "torrents",
                filename: "upload.torrent",
                contentType: "application/x-bittorrent",
                data: data,
                boundary: boundary,
                to: &body
            )
        }

        if !request.tags.isEmpty {
            Self.appendTextPart(
                name: "tags",
                value: request.tags.joined(separator: ","),
                boundary: boundary,
                to: &body
            )
        }
        Self.append("--\(boundary)--\r\n", to: &body)

        let response = try await performAPIRequest(
            path: ["torrents", "add"],
            method: .post,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        try validateMutationResponse(response.data)
    }
    #endif

    func getTorrent(id: String) async throws -> RemoteTorrent {
        let torrents = try await getTorrents(hashes: id)
        guard torrents.count == 1, let torrent = torrents.first else {
            throw ServerCommunicationError.invalidResponse
        }
        return torrent
    }

    func getTorrents() async throws -> [RemoteTorrent] {
        try await getTorrents(hashes: nil)
    }

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws {
        let path: [String]
        let parameters: [(String, String)]

        switch action {
        case .start:
            path = ["torrents", "start"]
            parameters = [("hashes", torrent.id)]
        case .stop:
            path = ["torrents", "stop"]
            parameters = [("hashes", torrent.id)]
        case .remove(let policy):
            path = ["torrents", "delete"]
            parameters = [
                ("hashes", torrent.id),
                ("deleteFiles", policy == .deleteLocalData ? "true" : "false")
            ]
        }

        let response = try await performAPIRequest(
            path: path,
            method: .post,
            body: Self.formData(parameters),
            contentType: "application/x-www-form-urlencoded"
        )
        try validateMutationResponse(response.data)
    }

    private func getTorrents(hashes: String?) async throws -> [RemoteTorrent] {
        let queryItems = hashes.map { [URLQueryItem(name: "hashes", value: $0)] } ?? []
        let response = try await performAPIRequest(
            path: ["torrents", "info"],
            method: .get,
            queryItems: queryItems
        )

        let remoteTorrents: [QBittorrent.Torrent]
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            remoteTorrents = try decoder.decode([QBittorrent.Torrent].self, from: response.data)
        } catch {
            throw ServerCommunicationError.parseError
        }

        let torrents = remoteTorrents.compactMap(RemoteTorrent.init(from:))
        guard torrents.count == remoteTorrents.count else {
            throw ServerCommunicationError.parseError
        }
        return torrents
    }

    private func ensureCompatibleVersion() async throws {
        if validatedVersion {
            return
        }
        if let versionTask {
            return try await versionTask.value
        }

        let task = Task {
            try await self.fetchAndValidateVersion()
        }
        versionTask = task

        do {
            try await task.value
            validatedVersion = true
            versionTask = nil
        } catch {
            versionTask = nil
            throw error
        }
    }

    private func fetchAndValidateVersion() async throws {
        let response = try await performAuthenticatedRequest(
            path: ["app", "version"],
            method: .get
        )
        guard let version = String(data: response.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let majorComponent = version
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".")
                .first,
              let major = Int(majorComponent),
              major >= 5 else {
            let version = String(data: response.data, encoding: .utf8) ?? "unknown"
            throw ServerCommunicationError.unsupportedServerVersion(version)
        }
    }

    private func performAPIRequest(
        path: [String],
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> Response {
        try await ensureCompatibleVersion()
        return try await performAuthenticatedRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            contentType: contentType
        )
    }

    private func performAuthenticatedRequest(
        path: [String],
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> Response {
        for attempt in 0...1 {
            try Task.checkCancellation()

            let requestSessionID = try await authenticatedSessionID()
            var request = try makeRequest(
                path: path,
                method: method,
                queryItems: queryItems,
                body: body,
                contentType: contentType
            )
            if let requestSessionID {
                let existingCookies = request.value(forHTTPHeaderField: "Cookie")?
                    .split(separator: ";")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { cookie in
                        cookie.split(separator: "=", maxSplits: 1).first?
                            .trimmingCharacters(in: .whitespaces)
                            != "SID"
                    } ?? []
                request.setValue(
                    (existingCookies + ["SID=\(requestSessionID)"]).joined(separator: "; "),
                    forHTTPHeaderField: "Cookie"
                )
            }

            let response = try await execute(request)
            if response.http.statusCode == 403,
               attempt == 0,
               connectionDetails.credentials != nil {
                if sessionID == requestSessionID {
                    sessionID = nil
                }
                continue
            }

            guard (200..<300).contains(response.http.statusCode) else {
                throw ServerCommunicationError.httpStatus(response.http.statusCode)
            }
            return response
        }

        throw ServerCommunicationError.authenticationFailed
    }

    private func authenticatedSessionID() async throws -> String? {
        guard connectionDetails.credentials != nil else {
            return nil
        }
        if let sessionID {
            return sessionID
        }
        if let authenticationTask {
            return try await authenticationTask.value
        }

        let task = Task {
            try await self.login()
        }
        authenticationTask = task

        do {
            let sessionID = try await task.value
            self.sessionID = sessionID
            authenticationTask = nil
            return sessionID
        } catch {
            authenticationTask = nil
            throw error
        }
    }

    private func login() async throws -> String {
        guard let credentials = connectionDetails.credentials else {
            throw ServerCommunicationError.authenticationFailed
        }

        let body = Self.formData([
            ("username", credentials.username),
            ("password", credentials.password)
        ])
        let request = try makeRequest(
            path: ["auth", "login"],
            method: .post,
            body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let response = try await execute(request)

        guard response.http.statusCode != 403 else {
            throw ServerCommunicationError.authenticationFailed
        }
        guard (200..<300).contains(response.http.statusCode) else {
            throw ServerCommunicationError.httpStatus(response.http.statusCode)
        }
        let result = String(data: response.data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard result == "Ok.",
              let sessionID = Self.sessionID(from: response.http),
              !sessionID.isEmpty else {
            throw ServerCommunicationError.authenticationFailed
        }
        return sessionID
    }

    private func makeRequest(
        path: [String],
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        contentType: String? = nil
    ) throws -> URLRequest {
        var url = connectionDetails.endpoint
        for component in ["api", "v2"] + path {
            url.appendPathComponent(component)
        }
        if !queryItems.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw ServerCommunicationError.invalidResponse
            }
            components.queryItems = queryItems
            guard let queryURL = components.url else {
                throw ServerCommunicationError.invalidResponse
            }
            url = queryURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        connectionDetails.applyCustomHeaders(to: &request)
        request.setValue(try referer(), forHTTPHeaderField: "Referer")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func referer() throws -> String {
        guard let scheme = connectionDetails.endpoint.scheme,
              let host = connectionDetails.endpoint.host else {
            throw ServerCommunicationError.invalidResponse
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = connectionDetails.endpoint.port
        components.path = "/"
        guard let value = components.url?.absoluteString else {
            throw ServerCommunicationError.invalidResponse
        }
        return value
    }

    private func execute(_ request: URLRequest) async throws -> Response {
        do {
            let (data, response) = try await session.data(
                for: request,
                delegate: redirectDelegate
            )
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else {
                throw ServerCommunicationError.invalidResponse
            }
            return Response(data: data, http: http)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw ServerCommunicationError.connectivity(error, endpoint: connectionDetails.endpoint)
        } catch let error as ServerCommunicationError {
            throw error
        } catch {
            throw ServerCommunicationError.serverError(error.localizedDescription)
        }
    }

    private func validateMutationResponse(_ data: Data) throws {
        let value = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if value?.caseInsensitiveCompare("Fails.") == .orderedSame {
            throw ServerCommunicationError.serverError("qBittorrent rejected the request.")
        }
    }

    private static func sessionID(from response: HTTPURLResponse) -> String? {
        guard let url = response.url else {
            return nil
        }
        let fields = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String, let value = entry.value as? String else {
                return
            }
            result[key] = value
        }
        return HTTPCookie.cookies(withResponseHeaderFields: fields, for: url)
            .first(where: { $0.name == "SID" })?
            .value
    }

    private static func formData(_ parameters: [(String, String)]) -> Data {
        let value = parameters.map { name, value in
            "\(formEncoded(name))=\(formEncoded(value))"
        }.joined(separator: "&")
        return Data(value.utf8)
    }

    private static func formEncoded(_ value: String) -> String {
        value.utf8.map { byte -> String in
            switch byte {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2A, 0x2D, 0x2E, 0x5F:
                return String(UnicodeScalar(byte))
            case 0x20:
                return "+"
            default:
                return String(format: "%%%02X", byte)
            }
        }.joined()
    }

    private static func appendTextPart(
        name: String,
        value: String,
        boundary: String,
        to body: inout Data
    ) {
        append("--\(boundary)\r\n", to: &body)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n", to: &body)
        append("\(value)\r\n", to: &body)
    }

    private static func appendFilePart(
        name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String,
        to body: inout Data
    ) {
        append("--\(boundary)\r\n", to: &body)
        append(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n",
            to: &body
        )
        append("Content-Type: \(contentType)\r\n\r\n", to: &body)
        body.append(data)
        append("\r\n", to: &body)
    }

    private static func append(_ string: String, to data: inout Data) {
        data.append(Data(string.utf8))
    }
}

extension QBittorrentConnection: TorrentTagProviding {

    func availableTags() async throws -> [String] {
        let response = try await performAPIRequest(
            path: ["torrents", "tags"],
            method: .get
        )
        do {
            return try JSONDecoder().decode([String].self, from: response.data).sorted()
        } catch {
            throw ServerCommunicationError.parseError
        }
    }
}

extension QBittorrentConnection: GlobalSpeedLimitSupporting {

    func globalSpeedLimits() async throws -> GlobalSpeedLimits {
        async let download = transferLimit(path: "downloadLimit")
        async let upload = transferLimit(path: "uploadLimit")
        let (downloadLimit, uploadLimit) = try await (download, upload)
        return .init(
            download: .init(
                bytesPerSecond: downloadLimit,
                isEnabled: downloadLimit > 0
            ),
            upload: .init(
                bytesPerSecond: uploadLimit,
                isEnabled: uploadLimit > 0
            )
        )
    }

    func setGlobalSpeedLimits(_ limits: GlobalSpeedLimits) async throws {
        try Self.validate(limits.download)
        try Self.validate(limits.upload)

        try await setTransferLimit(
            path: "setDownloadLimit",
            limit: limits.download.isEnabled ? limits.download.bytesPerSecond : 0
        )
        try await setTransferLimit(
            path: "setUploadLimit",
            limit: limits.upload.isEnabled ? limits.upload.bytesPerSecond : 0
        )
    }

    private func transferLimit(path: String) async throws -> Int64 {
        let response = try await performAPIRequest(
            path: ["transfer", path],
            method: .get
        )
        guard let value = String(data: response.data, encoding: .utf8)
            .flatMap({ Int64($0.trimmingCharacters(in: .whitespacesAndNewlines)) }),
              value >= 0 else {
            throw ServerCommunicationError.parseError
        }
        return value
    }

    private func setTransferLimit(path: String, limit: Int64) async throws {
        let response = try await performAPIRequest(
            path: ["transfer", path],
            method: .post,
            body: Self.formData([("limit", String(limit))]),
            contentType: "application/x-www-form-urlencoded"
        )
        try validateMutationResponse(response.data)
    }

    private static func validate(_ limit: TransferRateLimit) throws {
        guard limit.bytesPerSecond >= 0,
              !limit.isEnabled || limit.bytesPerSecond > 0 else {
            throw ServerCommunicationError.serverError(
                "Enabled speed limits must be greater than zero."
            )
        }
    }
}
