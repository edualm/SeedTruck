//
//  TransmissionConnectionTests.swift
//  Tests iOS
//

import XCTest
@testable import SeedTruck

final class TransmissionConnectionTests: XCTestCase {

    private enum FixtureError: Error {

        case invalidRequest
    }

    private final class LockedCounter: @unchecked Sendable {

        private let lock = NSLock()
        private var value = 0

        func increment() -> Int {
            lock.lock()
            defer { lock.unlock() }
            value += 1
            return value
        }
    }

    private static func requestJSON(from body: Data?) throws -> [String: Any] {
        guard let body,
              let json = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw FixtureError.invalidRequest
        }
        return json
    }

    private static func requestID(from body: Data?) throws -> String {
        guard let id = try requestJSON(from: body)["id"] as? String else {
            throw FixtureError.invalidRequest
        }
        return id
    }

    private static func successResponse(
        for body: Data?,
        result: [String: Any] = [:]
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "result": result,
            "id": requestID(from: body)
        ])
    }

    private static func errorResponse(
        for body: Data?,
        code: Int,
        message: String,
        detail: String? = nil
    ) throws -> Data {
        var error: [String: Any] = [
            "code": code,
            "message": message
        ]
        if let detail {
            error["data"] = ["error_string": detail]
        }
        return try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "error": error,
            "id": requestID(from: body)
        ])
    }

    private var torrent: RemoteTorrent {
        RemoteTorrent(
            id: "42",
            name: "Action fixture",
            progress: 0.5,
            status: .stopped,
            size: 1_000,
            labels: []
        )
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    private func makeConnection(
        username: String? = nil,
        password: String? = nil,
        customHeaders: [ConnectionDetails.CustomHeader] = []
    ) -> TransmissionConnection {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]

        let credentials: ConnectionDetails.Credentials?
        if let username, let password {
            credentials = .init(username: username, password: password)
        } else {
            credentials = nil
        }

        return TransmissionConnection(
            connectionDetails: .init(
                type: .transmission,
                endpoint: URL(string: "https://example.com/transmission/rpc")!,
                credentials: credentials,
                customHeaders: customHeaders
            ),
            session: URLSession(configuration: configuration)
        )
    }

    func testAddsBasicAuthenticationHeader() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(for: body, result: ["torrents": []]))
        }

        _ = try await makeConnection(username: "user", password: "secret").getTorrents()

        XCTAssertEqual(
            URLProtocolStub.requests.first?.value(forHTTPHeaderField: "Authorization"),
            "Basic dXNlcjpzZWNyZXQ="
        )
    }

    func testAddsCustomHeadersWithoutOverridingManagedHeaders() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(for: body, result: ["torrents": []]))
        }

        _ = try await makeConnection(
            username: "user",
            password: "secret",
            customHeaders: [
                .init(name: "X-Proxy-Token", value: "proxy-secret"),
                .init(name: "Authorization", value: "Bearer custom"),
                .init(name: "Content-Type", value: "text/plain")
            ]
        ).getTorrents()

        let request = try XCTUnwrap(URLProtocolStub.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Proxy-Token"), "proxy-secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic dXNlcjpzZWNyZXQ=")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testRetries409OnceAndRetainsToken() async throws {
        URLProtocolStub.setHandler { request, body in
            if request.value(forHTTPHeaderField: "X-Transmission-Session-Id") == nil {
                return .init(
                    statusCode: 409,
                    headers: ["X-Transmission-Session-Id": "token-1"]
                )
            }

            return .init(data: try Self.successResponse(for: body, result: ["torrents": []]))
        }

        let connection = makeConnection()
        _ = try await connection.getTorrents()
        _ = try await connection.getTorrents()

        XCTAssertEqual(URLProtocolStub.requests.count, 3)
        XCTAssertEqual(
            URLProtocolStub.requests[1].value(forHTTPHeaderField: "X-Transmission-Session-Id"),
            "token-1"
        )
        XCTAssertEqual(
            URLProtocolStub.requests[2].value(forHTTPHeaderField: "X-Transmission-Session-Id"),
            "token-1"
        )
        XCTAssertEqual(
            try Self.requestID(from: URLProtocolStub.requestBodies[0]),
            try Self.requestID(from: URLProtocolStub.requestBodies[1])
        )
        XCTAssertNotEqual(
            try Self.requestID(from: URLProtocolStub.requestBodies[1]),
            try Self.requestID(from: URLProtocolStub.requestBodies[2])
        )
    }

    func testStale409DoesNotOverwriteNewerToken() async throws {
        let tokenlessRequestCount = LockedCounter()

        URLProtocolStub.setHandler { request, body in
            guard request.value(forHTTPHeaderField: "X-Transmission-Session-Id") == nil else {
                return .init(data: try Self.successResponse(for: body, result: ["torrents": []]))
            }

            let requestOrdinal = tokenlessRequestCount.increment()

            if requestOrdinal == 1 {
                return .init(
                    statusCode: 409,
                    headers: ["X-Transmission-Session-Id": "token-old"],
                    delay: 0.1
                )
            }

            return .init(
                statusCode: 409,
                headers: ["X-Transmission-Session-Id": "token-new"],
                delay: 0.01
            )
        }

        let connection = makeConnection()
        async let first = connection.getTorrents()
        async let second = connection.getTorrents()
        _ = try await (first, second)

        XCTAssertEqual(URLProtocolStub.requests.count, 4)
        XCTAssertEqual(
            URLProtocolStub.requests[2].value(forHTTPHeaderField: "X-Transmission-Session-Id"),
            "token-new"
        )
        XCTAssertEqual(
            URLProtocolStub.requests[3].value(forHTTPHeaderField: "X-Transmission-Session-Id"),
            "token-new"
        )
    }

    func testRejectsSecond409() async {
        URLProtocolStub.setHandler { _, _ in
            .init(
                statusCode: 409,
                headers: ["X-Transmission-Session-Id": "token"]
            )
        }

        do {
            _ = try await makeConnection().getTorrents()
            XCTFail("Expected the repeated handshake to fail")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .invalidResponse)
            XCTAssertEqual(URLProtocolStub.requests.count, 2)
        }
    }

    func testRejectsNonSuccessHTTPStatus() async {
        URLProtocolStub.setHandler { _, _ in
            .init(statusCode: 404)
        }

        do {
            _ = try await makeConnection().getTorrents()
            XCTFail("Expected the HTTP error to be surfaced")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .httpStatus(404))
        }
    }

    func testRejectsRPCError() async {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.errorResponse(
                for: body,
                code: 3,
                message: "Permission denied",
                detail: "The request is not allowed"
            ))
        }

        do {
            _ = try await makeConnection().getTorrents()
            XCTFail("Expected the RPC error to be surfaced")
        } catch {
            XCTAssertEqual(
                error as? ServerCommunicationError,
                .serverError("Permission denied: The request is not allowed")
            )
        }
    }

    func testRejectsMismatchedJSONRPCResponseID() async {
        URLProtocolStub.setHandler { _, _ in
            .init(data: try JSONSerialization.data(withJSONObject: [
                "jsonrpc": "2.0",
                "result": ["torrents": []],
                "id": "a-different-request"
            ]))
        }

        do {
            _ = try await makeConnection().getTorrents()
            XCTFail("Expected the mismatched response ID to fail")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .invalidResponse)
        }
    }

    func testRejectsLegacyRPCResponse() async {
        URLProtocolStub.setHandler { _, _ in
            .init(data: Data(#"{"arguments":{"torrents":[]},"result":"success"}"#.utf8))
        }

        do {
            _ = try await makeConnection().getTorrents()
            XCTFail("Expected the legacy response to fail")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .parseError)
        }
    }

    func testRejectsResponseContainingResultAndError() async {
        URLProtocolStub.setHandler { _, body in
            .init(data: try JSONSerialization.data(withJSONObject: [
                "jsonrpc": "2.0",
                "result": ["torrents": []],
                "error": ["code": 1, "message": "Invalid response"],
                "id": Self.requestID(from: body)
            ]))
        }

        do {
            _ = try await makeConnection().getTorrents()
            XCTFail("Expected an ambiguous response to fail")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .invalidResponse)
        }
    }

    func testCancellationCancelsRequest() async {
        URLProtocolStub.setHandler { _, body in
            .init(
                data: try Self.successResponse(for: body, result: ["torrents": []]),
                delay: 5
            )
        }

        let connection = makeConnection()
        let task = Task {
            try await connection.getTorrents()
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMapsDetailedTorrentFieldsAndCheckingStatus() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(
                for: body,
                result: [
                    "torrents": [[
                        "id": 42,
                        "name": "Checking fixture",
                        "percent_done": 0.8,
                        "recheck_progress": 0.35,
                        "status": 2,
                        "size_when_done": 4_000,
                        "peers_connected": 7,
                        "peers_sending_to_us": 3,
                        "peers_getting_from_us": 2,
                        "rate_download": 1_024,
                        "rate_upload": 512,
                        "uploaded_ever": 2_000,
                        "downloaded_ever": 3_000,
                        "upload_ratio": 0.5,
                        "seconds_downloading": 90,
                        "seconds_seeding": 0,
                        "queue_position": 1,
                        "eta": -2,
                        "eta_idle": -1,
                        "labels": ["Archive"]
                    ]]
                ]
            ))
        }

        let torrents = try await makeConnection().getTorrents()
        let mapped = try XCTUnwrap(torrents.first)

        XCTAssertEqual(mapped.status, .checking)
        XCTAssertEqual(mapped.verificationProgress, 0.35)
        XCTAssertEqual(mapped.statistics.peersConnected, 7)
        XCTAssertEqual(mapped.statistics.downloadingFrom, 3)
        XCTAssertEqual(mapped.statistics.uploadingTo, 2)
        XCTAssertEqual(mapped.statistics.downloadedEver, 3_000)
        XCTAssertEqual(mapped.statistics.queuePosition, 1)
    }

    func testTorrentGetUsesJSONRPCEnvelopeAndSnakeCaseFields() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(for: body, result: ["torrents": []]))
        }

        _ = try await makeConnection().getTorrents()
        let body = try XCTUnwrap(URLProtocolStub.requestBodies.first ?? nil)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let parameters = try XCTUnwrap(json["params"] as? [String: Any])
        let fields = try XCTUnwrap(parameters["fields"] as? [String])

        XCTAssertEqual(json["jsonrpc"] as? String, "2.0")
        XCTAssertEqual(json["method"] as? String, "torrent_get")
        XCTAssertNotNil(json["id"] as? String)
        XCTAssertNil(json["arguments"])
        XCTAssertNil(json["tag"])
        XCTAssertNil(parameters["ids"])
        XCTAssertTrue(fields.contains("recheck_progress"))
        XCTAssertTrue(fields.contains("queue_position"))
        XCTAssertTrue(fields.contains("downloaded_ever"))
        XCTAssertTrue(fields.contains("seconds_downloading"))
    }

    func testAddsMagnetUsingJSONRPCParameters() async throws {
        URLProtocolStub.setHandler { _, body in
            let request = try Self.requestJSON(from: body)
            switch request["method"] as? String {
            case "torrent_add":
                return .init(data: try Self.successResponse(
                    for: body,
                    result: [
                        "torrent_added": [
                            "hash_string": "abcdef",
                            "id": 42,
                            "name": "Added fixture"
                        ]
                    ]
                ))
            default:
                throw FixtureError.invalidRequest
            }
        }
        let upload = TorrentAddRequest(
            torrent: .magnet("magnet:?xt=urn:btih:abcdef"),
            tags: ["Archive"]
        )

        try await makeConnection().addTorrent(upload)
        let addRequest = try Self.requestJSON(from: URLProtocolStub.requestBodies[0])
        let parameters = try XCTUnwrap(addRequest["params"] as? [String: Any])

        XCTAssertEqual(URLProtocolStub.requests.count, 1)
        XCTAssertEqual(addRequest["method"] as? String, "torrent_add")
        XCTAssertEqual(parameters["filename"] as? String, "magnet:?xt=urn:btih:abcdef")
        XCTAssertEqual(parameters["labels"] as? [String], ["Archive"])
        XCTAssertNil(parameters["metainfo"])
    }

    func testTorrentActionsUseQueueAwareMethodsAndExplicitRemovalPolicies() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(for: body))
        }
        let connection = makeConnection()

        _ = try await connection.perform(.start, on: torrent)
        _ = try await connection.perform(.stop, on: torrent)
        _ = try await connection.perform(.remove(.keepLocalData), on: torrent)
        _ = try await connection.perform(.remove(.deleteLocalData), on: torrent)

        let bodies = try URLProtocolStub.requestBodies.map { capturedBody -> [String: Any] in
            let body = try XCTUnwrap(capturedBody)
            return try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
        }
        XCTAssertEqual(bodies[0]["method"] as? String, "torrent_start")
        XCTAssertEqual(bodies[1]["method"] as? String, "torrent_stop")
        XCTAssertEqual(bodies[2]["method"] as? String, "torrent_remove")
        XCTAssertEqual(bodies[3]["method"] as? String, "torrent_remove")

        let keepParameters = try XCTUnwrap(bodies[2]["params"] as? [String: Any])
        let deleteParameters = try XCTUnwrap(bodies[3]["params"] as? [String: Any])
        XCTAssertEqual(keepParameters["delete_local_data"] as? Bool, false)
        XCTAssertEqual(deleteParameters["delete_local_data"] as? Bool, true)
    }

    func testGetsCanonicalSpeedLimitsFromNumericResponse() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(
                for: body,
                result: [
                    "speed_limit_down": 1_000.0,
                    "speed_limit_up": 500,
                    "speed_limit_down_enabled": true,
                    "speed_limit_up_enabled": false
                ]
            ))
        }

        let limits = try await makeConnection().globalSpeedLimits()
        let request = try Self.requestJSON(from: URLProtocolStub.requestBodies[0])
        let parameters = try XCTUnwrap(request["params"] as? [String: Any])
        let fields = try XCTUnwrap(parameters["fields"] as? [String])

        XCTAssertEqual(limits.download.bytesPerSecond, 1_000_000)
        XCTAssertEqual(limits.upload.bytesPerSecond, 500_000)
        XCTAssertTrue(limits.download.isEnabled)
        XCTAssertFalse(limits.upload.isEnabled)
        XCTAssertEqual(request["method"] as? String, "session_get")
        XCTAssertEqual(
            Set(fields),
            Set([
                "speed_limit_up",
                "speed_limit_down",
                "speed_limit_up_enabled",
                "speed_limit_down_enabled"
            ])
        )
    }

    func testRejectsNegativeSpeedLimitsBeforeScaling() async {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(
                for: body,
                result: [
                    "speed_limit_down": -9_223_372_036_855_000,
                    "speed_limit_up": 500,
                    "speed_limit_down_enabled": true,
                    "speed_limit_up_enabled": false
                ]
            ))
        }

        do {
            _ = try await makeConnection().globalSpeedLimits()
            XCTFail("Expected the negative speed limit to fail")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .parseError)
        }
    }

    func testSetsSpeedLimitsWithJSONRPCParameters() async throws {
        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(for: body))
        }

        try await makeConnection().setGlobalSpeedLimits(
            .init(
                download: .init(bytesPerSecond: 1_000_000, isEnabled: true),
                upload: .init(bytesPerSecond: 500_000, isEnabled: false)
            )
        )
        let body = try XCTUnwrap(URLProtocolStub.requestBodies.first ?? nil)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let parameters = try XCTUnwrap(json["params"] as? [String: Any])

        XCTAssertEqual(json["method"] as? String, "session_set")
        XCTAssertEqual(parameters["speed_limit_down"] as? Int, 1_000)
        XCTAssertEqual(parameters["speed_limit_up"] as? Int, 500)
        XCTAssertEqual(parameters["speed_limit_down_enabled"] as? Bool, true)
        XCTAssertEqual(parameters["speed_limit_up_enabled"] as? Bool, false)
    }

    @MainActor
    func testTorrentActionControllerEndsBusyStateAndRetainsRetryableFailure() async throws {
        URLProtocolStub.setHandler { _, _ in
            .init(statusCode: 500)
        }
        let controller = TorrentActionController()
        let identifier = TorrentActionIdentifier(
            serverID: UUID(),
            torrentID: torrent.id
        )
        let connection = makeConnection()

        controller.perform(
            .start,
            on: torrent,
            identifier: identifier,
            connection: connection
        )
        XCTAssertTrue(controller.activeActionIDs.contains(identifier))

        for _ in 0..<100 where controller.activeActionIDs.contains(identifier) {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(controller.activeActionIDs.contains(identifier))
        XCTAssertEqual(controller.failures[identifier]?.action, .start)

        URLProtocolStub.setHandler { _, body in
            .init(data: try Self.successResponse(for: body))
        }
        controller.perform(
            .start,
            on: torrent,
            identifier: identifier,
            connection: connection
        )

        for _ in 0..<100 where controller.activeActionIDs.contains(identifier) {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(controller.activeActionIDs.contains(identifier))
        XCTAssertNil(controller.failures[identifier])
    }

    @MainActor
    func testTorrentActionControllerClearsOnlyTheAlertedFailure() async throws {
        URLProtocolStub.setHandler { _, _ in
            .init(statusCode: 500)
        }
        let controller = TorrentActionController()
        let serverID = UUID()
        let firstIdentifier = TorrentActionIdentifier(serverID: serverID, torrentID: "first")
        let secondIdentifier = TorrentActionIdentifier(serverID: serverID, torrentID: "second")
        let connection = makeConnection()

        controller.perform(.start, on: torrent, identifier: firstIdentifier, connection: connection)
        for _ in 0..<100 where controller.activeActionIDs.contains(firstIdentifier) {
            try await Task.sleep(for: .milliseconds(10))
        }
        controller.perform(.start, on: torrent, identifier: secondIdentifier, connection: connection)
        for _ in 0..<100 where controller.activeActionIDs.contains(secondIdentifier) {
            try await Task.sleep(for: .milliseconds(10))
        }

        controller.clearAlertFailure()

        XCTAssertNotNil(controller.failures[firstIdentifier])
        XCTAssertNil(controller.failures[secondIdentifier])
        XCTAssertNil(controller.errorMessage)
    }

    @MainActor
    func testTorrentActionControllerReconcilesObservedActionResults() async throws {
        URLProtocolStub.setHandler { _, _ in
            .init(statusCode: 500)
        }
        let controller = TorrentActionController()
        let serverID = UUID()
        let startIdentifier = TorrentActionIdentifier(serverID: serverID, torrentID: "start")
        let stopIdentifier = TorrentActionIdentifier(serverID: serverID, torrentID: "stop")
        let removeIdentifier = TorrentActionIdentifier(serverID: serverID, torrentID: "remove")
        let connection = makeConnection()
        let startingTorrent = RemoteTorrent(
            id: startIdentifier.torrentID,
            name: "Starting fixture",
            progress: 0.5,
            status: .stopped,
            size: 1_000,
            labels: []
        )
        let stoppingTorrent = RemoteTorrent(
            id: stopIdentifier.torrentID,
            name: "Stopping fixture",
            progress: 0.5,
            status: .downloading,
            size: 1_000,
            labels: []
        )
        controller.perform(
            .start,
            on: startingTorrent,
            identifier: startIdentifier,
            connection: connection,
            showsErrorAlert: false
        )
        for _ in 0..<100 where controller.activeActionIDs.contains(startIdentifier) {
            try await Task.sleep(for: .milliseconds(10))
        }
        controller.perform(
            .stop,
            on: stoppingTorrent,
            identifier: stopIdentifier,
            connection: connection,
            showsErrorAlert: false
        )
        for _ in 0..<100 where controller.activeActionIDs.contains(stopIdentifier) {
            try await Task.sleep(for: .milliseconds(10))
        }
        controller.perform(
            .remove(.deleteLocalData),
            on: torrent,
            identifier: removeIdentifier,
            connection: connection,
            showsErrorAlert: false
        )
        for _ in 0..<100 where controller.activeActionIDs.contains(removeIdentifier) {
            try await Task.sleep(for: .milliseconds(10))
        }

        let runningTorrent = RemoteTorrent(
            id: startIdentifier.torrentID,
            name: startingTorrent.name,
            progress: startingTorrent.progress,
            status: .downloading,
            size: startingTorrent.size,
            labels: []
        )
        let stoppedTorrent = RemoteTorrent(
            id: stopIdentifier.torrentID,
            name: stoppingTorrent.name,
            progress: stoppingTorrent.progress,
            status: .stopped,
            size: stoppingTorrent.size,
            labels: []
        )
        controller.reconcileFailures(with: [runningTorrent, stoppedTorrent], serverID: serverID)

        XCTAssertNil(controller.failures[startIdentifier])
        XCTAssertNil(controller.failures[stopIdentifier])
        XCTAssertNil(controller.failures[removeIdentifier])
    }
}
