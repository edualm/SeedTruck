//
//  QBittorrentConnectionTests.swift
//  Tests iOS
//

import XCTest
@testable import SeedTruck

final class QBittorrentConnectionTests: XCTestCase {

    private enum FixtureError: Error {
        case invalidRequest
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testAuthenticatesOnceAndMapsTorrentList() async throws {
        URLProtocolStub.setHandler { request, body in
            switch request.url?.path {
            case "/qb/api/v2/auth/login":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://example.com/")
                XCTAssertEqual(String(data: body ?? Data(), encoding: .utf8), "username=user&password=p%40ss+word")
                return .init(
                    headers: ["Set-Cookie": "SID=session-1; Path=/; HttpOnly"],
                    data: Data("Ok.".utf8)
                )
            case "/qb/api/v2/app/version":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "SID=session-1")
                return .init(data: Data("v5.0.4".utf8))
            case "/qb/api/v2/torrents/info":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "SID=session-1")
                return .init(data: Self.torrentListData)
            default:
                throw FixtureError.invalidRequest
            }
        }

        let torrents = try await makeConnection().getTorrents()

        XCTAssertEqual(torrents.count, 1)
        XCTAssertEqual(torrents[0].id, "abcdef")
        XCTAssertEqual(torrents[0].status, .downloading)
        XCTAssertEqual(
            URLProtocolStub.requests.filter { $0.url?.path.hasSuffix("/auth/login") == true }.count,
            1
        )
    }

    func testAuthenticationBypassDoesNotAttemptLogin() async throws {
        URLProtocolStub.setHandler { request, _ in
            switch request.url?.path {
            case "/api/v2/app/version":
                return .init(data: Data("v5.1.0".utf8))
            case "/api/v2/torrents/info":
                XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
                return .init(data: Data("[]".utf8))
            default:
                throw FixtureError.invalidRequest
            }
        }

        let torrents = try await makeConnection(credentials: nil, endpoint: "https://example.com").getTorrents()

        XCTAssertTrue(torrents.isEmpty)
        XCTAssertFalse(URLProtocolStub.requests.contains { $0.url?.path.hasSuffix("/auth/login") == true })
    }

    func testAppliesCustomHeadersWithoutOverridingManagedHeaders() async throws {
        URLProtocolStub.setHandler { request, _ in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Proxy-Token"), "proxy-secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Referer"), "https://example.com/")

            switch request.url?.path {
            case "/qb/api/v2/auth/login":
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Content-Type"),
                    "application/x-www-form-urlencoded"
                )
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Cookie"),
                    "proxy-cookie=value; sid=proxy-token; SID=custom"
                )
                return .init(
                    headers: ["Set-Cookie": "SID=session-1; Path=/; HttpOnly"],
                    data: Data("Ok.".utf8)
                )
            case "/qb/api/v2/app/version":
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Cookie"),
                    "proxy-cookie=value; sid=proxy-token; SID=session-1"
                )
                return .init(data: Data("v5.0.4".utf8))
            case "/qb/api/v2/torrents/info":
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "Cookie"),
                    "proxy-cookie=value; sid=proxy-token; SID=session-1"
                )
                return .init(data: Data("[]".utf8))
            default:
                throw FixtureError.invalidRequest
            }
        }

        let torrents = try await makeConnection(customHeaders: [
            .init(name: "X-Proxy-Token", value: "proxy-secret"),
            .init(name: "Referer", value: "https://wrong.example/"),
            .init(name: "Content-Type", value: "text/plain"),
            .init(name: "Cookie", value: "proxy-cookie=value; sid=proxy-token; SID=custom")
        ]).getTorrents()

        XCTAssertTrue(torrents.isEmpty)
    }

    func testExpiredSessionRelogsInAndRetriesOnce() async throws {
        URLProtocolStub.setHandler { request, _ in
            switch request.url?.path {
            case "/qb/api/v2/auth/login":
                let loginCount = URLProtocolStub.requests.filter {
                    $0.url?.path.hasSuffix("/auth/login") == true
                }.count
                return .init(
                    headers: ["Set-Cookie": "SID=session-\(loginCount); Path=/"],
                    data: Data("Ok.".utf8)
                )
            case "/qb/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/qb/api/v2/torrents/info":
                if request.value(forHTTPHeaderField: "Cookie") == "SID=session-1" {
                    return .init(statusCode: 403)
                }
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cookie"), "SID=session-2")
                return .init(data: Self.torrentListData)
            default:
                throw FixtureError.invalidRequest
            }
        }

        let torrents = try await makeConnection().getTorrents()

        XCTAssertEqual(torrents.count, 1)
        XCTAssertEqual(
            URLProtocolStub.requests.filter { $0.url?.path.hasSuffix("/auth/login") == true }.count,
            2
        )
    }

    func testConcurrentExpiredRequestsShareOneRelogin() async throws {
        URLProtocolStub.setHandler { request, _ in
            switch request.url?.path {
            case "/qb/api/v2/auth/login":
                let loginCount = URLProtocolStub.requests.filter {
                    $0.url?.path.hasSuffix("/auth/login") == true
                }.count
                return .init(
                    headers: ["Set-Cookie": "SID=session-\(loginCount); Path=/"],
                    data: Data("Ok.".utf8),
                    delay: loginCount == 2 ? 0.05 : 0
                )
            case "/qb/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/qb/api/v2/torrents/info":
                let infoCount = URLProtocolStub.requests.filter {
                    $0.url?.path.hasSuffix("/torrents/info") == true
                }.count
                if infoCount > 1,
                   request.value(forHTTPHeaderField: "Cookie") == "SID=session-1" {
                    return .init(statusCode: 403)
                }
                return .init(data: Self.torrentListData)
            default:
                throw FixtureError.invalidRequest
            }
        }
        let connection = makeConnection()
        _ = try await connection.getTorrents()

        async let first = connection.getTorrents()
        async let second = connection.getTorrents()
        _ = try await (first, second)

        XCTAssertEqual(
            URLProtocolStub.requests.filter { $0.url?.path.hasSuffix("/auth/login") == true }.count,
            2
        )
    }

    func testConcurrentRequestsShareAuthenticationAndVersionChecks() async throws {
        URLProtocolStub.setHandler { request, _ in
            switch request.url?.path {
            case "/qb/api/v2/auth/login":
                return .init(
                    headers: ["Set-Cookie": "SID=session; Path=/"],
                    data: Data("Ok.".utf8),
                    delay: 0.05
                )
            case "/qb/api/v2/app/version":
                return .init(data: Data("v5.2.0".utf8))
            case "/qb/api/v2/torrents/info":
                return .init(data: Data("[]".utf8))
            case "/qb/api/v2/torrents/tags":
                return .init(data: Data(#"["Archive"]"#.utf8))
            default:
                throw FixtureError.invalidRequest
            }
        }
        let connection = makeConnection()

        async let torrents = connection.getTorrents()
        async let tags = connection.availableTags()
        _ = try await (torrents, tags)

        XCTAssertEqual(
            URLProtocolStub.requests.filter { $0.url?.path.hasSuffix("/auth/login") == true }.count,
            1
        )
        XCTAssertEqual(
            URLProtocolStub.requests.filter { $0.url?.path.hasSuffix("/app/version") == true }.count,
            1
        )
    }

    func testRejectsPreVersionFiveServer() async throws {
        URLProtocolStub.setHandler { request, _ in
            guard request.url?.path == "/api/v2/app/version" else {
                throw FixtureError.invalidRequest
            }
            return .init(data: Data("v4.6.7".utf8))
        }

        await XCTAssertThrowsErrorAsync(
            try await makeConnection(credentials: nil, endpoint: "https://example.com").checkConnection()
        ) { error in
            XCTAssertEqual(error as? ServerCommunicationError, .unsupportedServerVersion("v4.6.7"))
        }
    }

    func testRejectsFailedLoginEvenWhenHTTPStatusIsSuccessful() async {
        URLProtocolStub.setHandler { request, _ in
            guard request.url?.path == "/qb/api/v2/auth/login" else {
                throw FixtureError.invalidRequest
            }
            return .init(data: Data("Fails.".utf8))
        }

        await XCTAssertThrowsErrorAsync(try await makeConnection().checkConnection()) { error in
            XCTAssertEqual(error as? ServerCommunicationError, .authenticationFailed)
        }
        XCTAssertEqual(URLProtocolStub.requests.count, 1)
    }

    func testMapsRejectedMutationAndInvalidTorrentStatus() async throws {
        URLProtocolStub.setHandler { request, _ in
            switch request.url?.path {
            case "/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/api/v2/torrents/start":
                return .init(data: Data("Fails.".utf8))
            case "/api/v2/torrents/add":
                return .init(statusCode: 415)
            default:
                throw FixtureError.invalidRequest
            }
        }
        let connection = makeConnection(credentials: nil, endpoint: "https://example.com")

        await XCTAssertThrowsErrorAsync(
            try await connection.perform(.start, on: Self.remoteTorrent)
        ) { error in
            XCTAssertEqual(
                error as? ServerCommunicationError,
                .serverError("qBittorrent rejected the request.")
            )
        }
        await XCTAssertThrowsErrorAsync(
            try await connection.addTorrent(
                .init(torrent: .magnet("magnet:?xt=urn:btih:abcdef"))
            )
        ) { error in
            XCTAssertEqual(error as? ServerCommunicationError, .httpStatus(415))
        }
    }

    func testGetsTorrentByEncodedHash() async throws {
        URLProtocolStub.setHandler { request, _ in
            switch request.url?.path {
            case "/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/api/v2/torrents/info":
                XCTAssertEqual(
                    URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "hashes" })?.value,
                    "ab+c/123"
                )
                return .init(data: Self.torrentListData)
            default:
                throw FixtureError.invalidRequest
            }
        }

        let torrent = try await makeConnection(credentials: nil, endpoint: "https://example.com")
            .getTorrent(id: "ab+c/123")

        XCTAssertEqual(torrent.id, "abcdef")
    }

    func testAddsMagnetAndTagsUsingMultipartFormData() async throws {
        URLProtocolStub.setHandler { request, body in
            switch request.url?.path {
            case "/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/api/v2/torrents/add":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
                let bodyString = String(data: body ?? Data(), encoding: .utf8) ?? ""
                XCTAssertTrue(bodyString.contains("name=\"urls\""))
                XCTAssertTrue(bodyString.contains("magnet:?xt=urn:btih:abcdef"))
                XCTAssertTrue(bodyString.contains("name=\"tags\""))
                XCTAssertTrue(bodyString.contains("Archive,Linux"))
                return .init(data: Data("Ok.".utf8))
            default:
                throw FixtureError.invalidRequest
            }
        }
        let request = TorrentAddRequest(
            torrent: .magnet("magnet:?xt=urn:btih:abcdef"),
            tags: ["Archive", "Linux"]
        )

        try await makeConnection(credentials: nil, endpoint: "https://example.com")
            .addTorrent(request)
    }

    func testAddsMetainfoWithoutChangingBytes() async throws {
        let metainfo = Data([0, 1, 2, 13, 10, 255, 128])
        URLProtocolStub.setHandler { request, body in
            switch request.url?.path {
            case "/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/api/v2/torrents/add":
                XCTAssertNotNil(body?.range(of: metainfo))
                XCTAssertTrue(
                    String(data: body ?? Data(), encoding: .isoLatin1)?
                        .contains("application/x-bittorrent") == true
                )
                return .init(data: Data("Ok.".utf8))
            default:
                throw FixtureError.invalidRequest
            }
        }
        let localTorrent = LocalTorrent.torrent(
            data: metainfo,
            metadata: .init(name: "Fixture", isPrivate: nil, files: [], totalSize: 0)
        )

        try await makeConnection(credentials: nil, endpoint: "https://example.com")
            .addTorrent(.init(torrent: localTorrent))
    }

    func testActionsUseQbittorrentFiveEndpointsAndRemovalPolicies() async throws {
        URLProtocolStub.setHandler { request, body in
            if request.url?.path == "/api/v2/app/version" {
                return .init(data: Data("v5.0.0".utf8))
            }
            let bodyString = String(data: body ?? Data(), encoding: .utf8) ?? ""
            XCTAssertTrue(bodyString.contains("hashes=abcdef"))
            return .init(data: Data("Ok.".utf8))
        }
        let connection = makeConnection(credentials: nil, endpoint: "https://example.com")
        let torrent = Self.remoteTorrent

        try await connection.perform(.start, on: torrent)
        try await connection.perform(.stop, on: torrent)
        try await connection.perform(.remove(.keepLocalData), on: torrent)
        try await connection.perform(.remove(.deleteLocalData), on: torrent)

        XCTAssertEqual(
            URLProtocolStub.requests.compactMap { $0.url?.path }.filter { $0.contains("/torrents/") },
            [
                "/api/v2/torrents/start",
                "/api/v2/torrents/stop",
                "/api/v2/torrents/delete",
                "/api/v2/torrents/delete"
            ]
        )
        let deletionBodies = URLProtocolStub.requestBodies.compactMap { body in
            body.flatMap { String(data: $0, encoding: .utf8) }
        }.filter { $0.contains("deleteFiles") }
        XCTAssertTrue(deletionBodies[0].contains("deleteFiles=false"))
        XCTAssertTrue(deletionBodies[1].contains("deleteFiles=true"))
    }

    func testReadsAndWritesCanonicalGlobalSpeedLimits() async throws {
        URLProtocolStub.setHandler { request, body in
            switch request.url?.path {
            case "/api/v2/app/version":
                return .init(data: Data("v5.0.0".utf8))
            case "/api/v2/transfer/downloadLimit":
                return .init(data: Data("1000000".utf8))
            case "/api/v2/transfer/uploadLimit":
                return .init(data: Data("0".utf8))
            case "/api/v2/transfer/setDownloadLimit":
                XCTAssertEqual(String(data: body ?? Data(), encoding: .utf8), "limit=2000000")
                return .init()
            case "/api/v2/transfer/setUploadLimit":
                XCTAssertEqual(String(data: body ?? Data(), encoding: .utf8), "limit=0")
                return .init()
            default:
                throw FixtureError.invalidRequest
            }
        }
        let connection = makeConnection(credentials: nil, endpoint: "https://example.com")

        let limits = try await connection.globalSpeedLimits()
        XCTAssertEqual(limits.download, .init(bytesPerSecond: 1_000_000, isEnabled: true))
        XCTAssertEqual(limits.upload, .init(bytesPerSecond: 0, isEnabled: false))

        try await connection.setGlobalSpeedLimits(
            .init(
                download: .init(bytesPerSecond: 2_000_000, isEnabled: true),
                upload: .init(bytesPerSecond: 500_000, isEnabled: false)
            )
        )
    }

    func testCancellationIsPreserved() async throws {
        URLProtocolStub.setHandler { request, _ in
            if request.url?.path == "/api/v2/app/version" {
                return .init(data: Data("v5.0.0".utf8))
            }
            return .init(data: Data("[]".utf8), delay: 1)
        }
        let connection = makeConnection(credentials: nil, endpoint: "https://example.com")
        let task = Task { try await connection.getTorrents() }
        try await Task.sleep(for: .milliseconds(50))

        task.cancel()

        await XCTAssertThrowsErrorAsync(try await task.value) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    private func makeConnection(
        credentials: ConnectionDetails.Credentials? = .init(
            username: "user",
            password: "p@ss word"
        ),
        endpoint: String = "https://example.com/qb",
        customHeaders: [ConnectionDetails.CustomHeader] = []
    ) -> QBittorrentConnection {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return QBittorrentConnection(
            connectionDetails: .init(
                type: .qBittorrent,
                endpoint: URL(string: endpoint)!,
                credentials: credentials,
                customHeaders: customHeaders
            ),
            session: URLSession(configuration: configuration)
        )
    }

    private static let torrentListData = Data("""
    [{
        "hash": "abcdef",
        "name": "Fixture",
        "progress": 0.5,
        "state": "downloading",
        "size": 1000,
        "tags": "Archive",
        "dlspeed": 100,
        "upspeed": 50
    }]
    """.utf8)

    private static let remoteTorrent = RemoteTorrent(
        id: "abcdef",
        name: "Fixture",
        progress: 0.5,
        status: .downloading,
        size: 1_000,
        labels: []
    )
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
