//
//  Tests_iOS.swift
//  Tests iOS
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation
import XCTest
@testable import SeedTruck

final class Tests_iOS: XCTestCase {

    private func makeServer(
        id: UUID = UUID(),
        endpoint: String = "https://example.com/transmission/rpc",
        name: String = "Seedbox",
        type: ServerType = .transmission,
        credentials: ConnectionDetails.Credentials? = nil,
        customHeaders: [ConnectionDetails.CustomHeader] = []
    ) -> Server {
        Server(
            id: id,
            endpoint: URL(string: endpoint)!,
            name: name,
            type: type.rawValue,
            credentials: credentials,
            customHeaders: customHeaders
        )
    }

    private func makeTorrent(
        id: String,
        name: String,
        progress: Double,
        status: RemoteTorrent.Status,
        verificationProgress: Double? = nil,
        statistics: RemoteTorrent.Statistics = .empty
    ) -> RemoteTorrent {
        RemoteTorrent(
            id: id,
            name: name,
            progress: progress,
            status: status,
            size: 1_000,
            labels: [],
            verificationProgress: verificationProgress,
            statistics: statistics
        )
    }

    private func bencodedBytes(_ data: Data) -> Data {
        var encoded = Data("\(data.count):".utf8)
        encoded.append(data)
        return encoded
    }

    private func bencodedString(_ value: String) -> Data {
        bencodedBytes(Data(value.utf8))
    }

    private func bencodedInteger(_ value: Int64) -> Data {
        Data("i\(value)e".utf8)
    }

    private func bencodedList(_ values: [Data]) -> Data {
        var encoded = Data("l".utf8)
        values.forEach { encoded.append($0) }
        encoded.append(Data("e".utf8))
        return encoded
    }

    private func bencodedDictionary(_ entries: [String: Data]) -> Data {
        var encoded = Data("d".utf8)
        for (key, value) in entries.sorted(by: { $0.key < $1.key }) {
            encoded.append(bencodedString(key))
            encoded.append(value)
        }
        encoded.append(Data("e".utf8))
        return encoded
    }

    private func torrentDocument(info: [String: Data]) -> Data {
        bencodedDictionary([
            "announce": bencodedString("https://tracker.example/announce"),
            "info": bencodedDictionary(info)
        ])
    }

    private var torrentListFixtures: [RemoteTorrent] {
        [
            makeTorrent(id: "stopped", name: "Zulu", progress: 0.7, status: .stopped),
            makeTorrent(
                id: "downloading",
                name: "alpha",
                progress: 0.2,
                status: .downloading,
                statistics: .init(
                    peersConnected: 2,
                    downloadingFrom: 1,
                    uploadingTo: 1,
                    downloadRate: 300,
                    uploadRate: 100,
                    eta: 60
                )
            ),
            makeTorrent(
                id: "seeding",
                name: "Middle",
                progress: 0.9,
                status: .seeding,
                statistics: .init(
                    peersConnected: 3,
                    uploadRate: 500,
                    uploadedEver: 1_500,
                    uploadRatio: 1.5,
                    etaIdle: nil,
                    secondsSeeding: 120
                )
            ),
            makeTorrent(
                id: "other",
                name: "Beta",
                progress: 0.4,
                status: .checking,
                verificationProgress: 0.3
            )
        ]
    }

    func testAppModuleLoads() {
        XCTAssertEqual(PollingInterval.timeInterval(for: 2), 2)
    }

    func testSupportLinksTargetSeedTruckResourcesAndPrefillZendeskFields() throws {
        XCTAssertEqual(
            SeedTruckSupportLinks.helpCenterURL.absoluteString,
            "https://support.bittenapps.com/hc/en-us/sections/38450059271442-Seed-Truck"
        )
        XCTAssertEqual(
            SeedTruckSupportLinks.privacyPolicyURL.absoluteString,
            "https://bittenapps.com/privacy_policy/seedtruck"
        )
        XCTAssertEqual(SeedTruckSupportLinks.currentPlatformIdentifier, "ios")

        let iOSURL = SeedTruckSupportLinks.supportTicketURL(platformIdentifier: "ios")
        let iOSComponents = try XCTUnwrap(
            URLComponents(url: iOSURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(iOSComponents.scheme, "https")
        XCTAssertEqual(iOSComponents.host, "support.bittenapps.com")
        XCTAssertEqual(iOSComponents.path, "/hc/en-us/requests/new")
        XCTAssertEqual(iOSComponents.queryItems, [
            URLQueryItem(name: "tf_360020061259", value: "seed_truck"),
            URLQueryItem(name: "tf_360019930300", value: "ios")
        ])

        let macURL = SeedTruckSupportLinks.supportTicketURL(platformIdentifier: "macos")
        let macComponents = try XCTUnwrap(
            URLComponents(url: macURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(macComponents.queryItems, [
            URLQueryItem(name: "tf_360020061259", value: "seed_truck"),
            URLQueryItem(name: "tf_360019930300", value: "macos")
        ])
    }

    func testCompactTransferRateFormatting() {
        XCTAssertEqual(ByteCountFormatter.humanReadableCompactTransferRate(bytesPerSecond: 0), "0")
        XCTAssertEqual(ByteCountFormatter.humanReadableCompactTransferRate(bytesPerSecond: 496), "496B")
        XCTAssertEqual(ByteCountFormatter.humanReadableCompactTransferRate(bytesPerSecond: 1_024), "1K")
        XCTAssertEqual(ByteCountFormatter.humanReadableCompactTransferRate(bytesPerSecond: 2_621_440), "2.5M")
        XCTAssertEqual(ByteCountFormatter.humanReadableCompactTransferRate(bytesPerSecond: 12_582_912), "12M")
    }

    func testRefreshIntervalOptionsRoundTripStoredValues() {
        for option in RefreshIntervalOption.allCases {
            XCTAssertEqual(RefreshIntervalOption(storedValue: option.rawValue), option)
            XCTAssertFalse(option.label.isEmpty)
        }

        XCTAssertEqual(RefreshIntervalOption(storedValue: 999), .twoSeconds)
        XCTAssertEqual(RefreshIntervalOption(storedValue: 0), .manualOnly)
        XCTAssertEqual(RefreshIntervalOption.manualOnly.label, "Manual only")
    }

    func testTorrentListProjectionFiltersSearchesAndSummarizesSource() {
        let projection = TorrentListProjection(
            torrents: torrentListFixtures,
            filter: .downloading,
            query: " ALP ",
            sort: .name,
            sortDirection: .ascending
        )

        XCTAssertEqual(projection.torrents.map(\.id), ["downloading"])
        XCTAssertEqual(projection.summary.visibleCount, 1)
        XCTAssertEqual(projection.summary.totalCount, 4)
        XCTAssertEqual(projection.summary.downloadSpeed, 300)
        XCTAssertEqual(projection.summary.uploadSpeed, 600)
        XCTAssertEqual(projection.summary.countLabel, "1 of 4")
        XCTAssertTrue(projection.isFiltered)

        let unfiltered = TorrentListProjection(
            torrents: torrentListFixtures,
            filter: nil,
            query: "   ",
            sort: .name,
            sortDirection: .ascending
        )
        XCTAssertEqual(unfiltered.summary.countLabel, "4")
        XCTAssertFalse(unfiltered.isFiltered)
    }

    func testTorrentListProjectionSupportsStableSortOptions() {
        let fixtures = torrentListFixtures
        func sortedIDs(by sort: TorrentSort, direction: TorrentSortDirection) -> [String] {
            TorrentListProjection(
                torrents: fixtures,
                filter: nil,
                query: "",
                sort: sort,
                sortDirection: direction
            ).torrents.map(\.id)
        }

        XCTAssertEqual(
            sortedIDs(by: .name, direction: .ascending),
            ["downloading", "other", "seeding", "stopped"]
        )
        XCTAssertEqual(
            sortedIDs(by: .name, direction: .descending),
            ["stopped", "seeding", "other", "downloading"]
        )
        XCTAssertEqual(
            sortedIDs(by: .activity, direction: .ascending),
            ["downloading", "seeding", "other", "stopped"]
        )
        XCTAssertEqual(
            sortedIDs(by: .activity, direction: .descending),
            ["stopped", "other", "seeding", "downloading"]
        )
        XCTAssertEqual(
            sortedIDs(by: .progress, direction: .ascending),
            ["downloading", "other", "stopped", "seeding"]
        )
        XCTAssertEqual(
            sortedIDs(by: .progress, direction: .descending),
            ["seeding", "stopped", "other", "downloading"]
        )
        XCTAssertEqual(
            sortedIDs(by: .speed, direction: .ascending),
            ["other", "stopped", "downloading", "seeding"]
        )
        XCTAssertEqual(
            sortedIDs(by: .speed, direction: .descending),
            ["seeding", "downloading", "other", "stopped"]
        )
    }

    func testTorrentListPresentationDistinguishesInitialLoadedAndStaleStates() {
        let emptyProjection = TorrentListProjection(
            torrents: [],
            filter: nil,
            query: "",
            sort: .name,
            sortDirection: .ascending
        )
        let contentProjection = TorrentListProjection(
            torrents: torrentListFixtures,
            filter: nil,
            query: "",
            sort: .name,
            sortDirection: .ascending
        )
        let noResultsProjection = TorrentListProjection(
            torrents: torrentListFixtures,
            filter: .stopped,
            query: "not present",
            sort: .name,
            sortDirection: .ascending
        )

        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: false,
                hasLoaded: false,
                isRefreshing: false,
                refreshError: nil,
                projection: emptyProjection
            ),
            .noServer
        )
        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: true,
                hasLoaded: false,
                isRefreshing: false,
                refreshError: nil,
                projection: emptyProjection
            ),
            .initialLoading
        )
        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: true,
                hasLoaded: false,
                isRefreshing: false,
                refreshError: "Offline",
                projection: emptyProjection
            ),
            .initialError("Offline")
        )
        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: true,
                hasLoaded: false,
                isRefreshing: true,
                refreshError: "Offline",
                projection: emptyProjection
            ),
            .initialLoading
        )
        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: true,
                hasLoaded: true,
                isRefreshing: true,
                refreshError: nil,
                projection: emptyProjection
            ),
            .empty(isRefreshing: true, refreshError: nil)
        )
        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: true,
                hasLoaded: true,
                isRefreshing: false,
                refreshError: "Timed out",
                projection: noResultsProjection
            ),
            .noResults(noResultsProjection, isRefreshing: false, refreshError: "Timed out")
        )
        XCTAssertEqual(
            TorrentListPresentationState(
                hasServer: true,
                hasLoaded: true,
                isRefreshing: false,
                refreshError: "Timed out",
                projection: contentProjection
            ),
            .content(contentProjection, isRefreshing: false, refreshError: "Timed out")
        )
    }

    func testTorrentDisplayMetadataAndPrimaryActionsAreComplete() {
        for filter in Filter.allCases {
            XCTAssertFalse(filter.label.isEmpty)
            XCTAssertFalse(filter.systemImage.isEmpty)
        }
        for sort in TorrentSort.allCases {
            XCTAssertFalse(sort.label.isEmpty)
            XCTAssertFalse(sort.systemImage.isEmpty)
        }
        for direction in TorrentSortDirection.allCases {
            XCTAssertFalse(direction.label.isEmpty)
            XCTAssertFalse(direction.systemImage.isEmpty)
        }

        XCTAssertEqual(torrentListFixtures[0].primaryAction, .start)
        XCTAssertEqual(torrentListFixtures[1].primaryAction, .stop)
        XCTAssertEqual(torrentListFixtures[2].primaryAction, .stop)
        XCTAssertEqual(torrentListFixtures[3].primaryAction, .stop)
        XCTAssertEqual(makeTorrent(id: "low", name: "Low", progress: -1, status: .stopped).normalizedProgress, 0)
        XCTAssertEqual(makeTorrent(id: "high", name: "High", progress: 2, status: .stopped).normalizedProgress, 1)
    }

    func testTorrentStatusDistinctionsAndCapabilitiesArePreserved() {
        let expectations: [(Int, RemoteTorrent.Status, Filter, RemoteTorrent.Action?)] = [
            (0, .stopped, .stopped, .start),
            (1, .queuedForCheck, .other, .stop),
            (2, .checking, .other, .stop),
            (3, .queuedForDownload, .downloading, .stop),
            (4, .downloading, .downloading, .stop),
            (5, .queuedForSeed, .seeding, .stop),
            (6, .seeding, .seeding, .stop),
            (99, .unknown("99"), .other, nil)
        ]

        for (code, status, filter, action) in expectations {
            let torrent = makeTorrent(
                id: "\(code)",
                name: "Status \(code)",
                progress: 0.5,
                status: .init(transmissionCode: code)
            )
            XCTAssertEqual(torrent.status, status)
            XCTAssertEqual(torrent.status.simple, filter)
            XCTAssertEqual(torrent.primaryAction, action)
            XCTAssertFalse(torrent.status.displayableStatus.isEmpty)
        }
    }

    func testTorrentDetailProjectionUsesVerificationProgressAndDirectionalPeers() {
        let torrent = RemoteTorrent(
            id: "checking",
            name: "Checking fixture",
            progress: 0.75,
            status: .checking,
            size: 4_000,
            labels: ["Archive"],
            verificationProgress: 0.32,
            statistics: .init(
                peersConnected: 7,
                downloadingFrom: 3,
                uploadingTo: 2,
                downloadRate: 1_024,
                uploadRate: 512,
                uploadedEver: 2_000,
                downloadedEver: 3_000,
                uploadRatio: 0.5,
                queuePosition: 1
            )
        )

        let projection = TorrentDetailProjection(torrent: torrent)
        let metrics = Dictionary(uniqueKeysWithValues: projection.metrics.map { ($0.id, $0) })

        XCTAssertEqual(projection.progress.kind, .verification)
        XCTAssertEqual(projection.progress.fraction, 0.32)
        XCTAssertEqual(projection.progress.percentageText, "32%")
        XCTAssertEqual(projection.primaryAction, .stop)
        XCTAssertEqual(metrics[.connectedPeers]?.value, "7")
        XCTAssertEqual(metrics[.downloadingFrom]?.label, "Downloading from")
        XCTAssertEqual(metrics[.downloadingFrom]?.value, "3")
        XCTAssertEqual(metrics[.uploadingTo]?.label, "Uploading to")
        XCTAssertEqual(metrics[.uploadingTo]?.value, "2")

        let stopped = makeTorrent(
            id: "stopped",
            name: "Stopped incomplete",
            progress: 0.41,
            status: .stopped
        )
        XCTAssertEqual(TorrentDetailProjection(torrent: stopped).progress.fraction, 0.41)
    }

    func testTorrentDetailProjectionHandlesQueueETAAndRatioSentinels() {
        let torrent = RemoteTorrent(
            id: "queued",
            name: "Queued fixture",
            progress: 0.2,
            status: .queuedForDownload,
            size: 5_000,
            labels: [],
            statistics: .init(uploadRatio: -2, eta: -2, queuePosition: 2)
        )

        let projection = TorrentDetailProjection(torrent: torrent)
        let metrics = Dictionary(uniqueKeysWithValues: projection.metrics.map { ($0.id, $0.value) })

        XCTAssertEqual(projection.etaText, "Unknown")
        XCTAssertEqual(metrics[.queuePosition], "3")
        XCTAssertEqual(metrics[.ratio], "Infinite")
    }

    func testTorrentDetailProjectionHidesOnlyUnavailableIdleLimits() {
        for etaIdle in [nil, Int64(-1)] {
            let torrent = RemoteTorrent(
                id: "unavailable-idle-limit",
                name: "Unavailable idle limit",
                progress: 1,
                status: .seeding,
                size: 5_000,
                labels: [],
                statistics: .init(etaIdle: etaIdle)
            )

            XCTAssertNil(TorrentDetailProjection(torrent: torrent).etaLabel)
        }

        let available = RemoteTorrent(
            id: "available-idle-limit",
            name: "Available idle limit",
            progress: 1,
            status: .seeding,
            size: 5_000,
            labels: [],
            statistics: .init(etaIdle: 900)
        )
        let availableProjection = TorrentDetailProjection(torrent: available)
        XCTAssertEqual(availableProjection.etaLabel, "Idle limit")
        XCTAssertNotEqual(availableProjection.etaText, "Not available")

        let unknown = RemoteTorrent(
            id: "unknown-idle-limit",
            name: "Unknown idle limit",
            progress: 1,
            status: .seeding,
            size: 5_000,
            labels: [],
            statistics: .init(etaIdle: -2)
        )
        let unknownProjection = TorrentDetailProjection(torrent: unknown)
        XCTAssertEqual(unknownProjection.etaLabel, "Idle limit")
        XCTAssertEqual(unknownProjection.etaText, "Unknown")
    }

    func testTorrentRemovalConfirmationsDescribeExactFilePolicy() {
        let torrent = makeTorrent(
            id: "remove",
            name: "Important Download",
            progress: 1,
            status: .stopped
        )
        let keep = TorrentRemovalConfirmation(torrent: torrent, policy: .keepLocalData)
        let delete = TorrentRemovalConfirmation(torrent: torrent, policy: .deleteLocalData)

        XCTAssertTrue(keep.message.contains("Important Download"))
        XCTAssertTrue(
            keep.message.contains(
                ByteCountFormatter.humanReadableFileSize(bytes: torrent.size)
            )
        )
        XCTAssertTrue(keep.message.contains("remain on disk"))
        XCTAssertEqual(keep.confirmButtonTitle, "Remove and Keep Files")
        XCTAssertTrue(delete.message.contains("permanently delete"))
        XCTAssertEqual(delete.confirmButtonTitle, "Remove and Delete Files")
    }

    func testTorrentPreviewEscapesUntrustedMetadata() {
        let metadata = LocalTorrent.Metadata(
            name: "Archive <script>alert('name')</script> & more",
            isPrivate: true,
            files: [
                .init(path: "Folder/<img src=x onerror=alert(1)>.txt", size: 1_024)
            ],
            totalSize: 1_024
        )

        let html = String(
            decoding: TorrentPreviewHTMLRenderer.preview(
                for: metadata,
                sourceFileName: "source<script>.torrent"
            ),
            as: UTF8.self
        )

        XCTAssertTrue(html.contains("Archive &lt;script&gt;alert(&#39;name&#39;)&lt;/script&gt; &amp; more"))
        XCTAssertTrue(html.contains("Folder/&lt;img src=x onerror=alert(1)&gt;.txt"))
        XCTAssertTrue(html.contains("source&lt;script&gt;.torrent"))
        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("<strong>Private</strong>"))
    }

    func testTorrentPreviewDescribesExplicitPrivacyStates() {
        func html(isPrivate: Bool?) -> String {
            let metadata = LocalTorrent.Metadata(
                name: "Archive",
                isPrivate: isPrivate,
                files: [.init(path: "archive.bin", size: 1)],
                totalSize: 1
            )
            return String(
                decoding: TorrentPreviewHTMLRenderer.preview(
                    for: metadata,
                    sourceFileName: "archive.torrent"
                ),
                as: UTF8.self
            )
        }

        XCTAssertTrue(html(isPrivate: true).contains("<strong>Private</strong>"))
        XCTAssertTrue(html(isPrivate: false).contains("<strong>Public</strong>"))
        XCTAssertFalse(html(isPrivate: nil).contains("<span class=\"label\">Access</span>"))
    }

    func testTorrentPreviewBoundsLargeFileLists() {
        let files = (0..<(TorrentPreviewHTMLRenderer.maximumDisplayedFiles + 2)).map {
            LocalTorrent.File(path: "file-\($0).bin", size: Int64($0))
        }
        let metadata = LocalTorrent.Metadata(
            name: "Large archive",
            isPrivate: nil,
            files: files,
            totalSize: files.reduce(0, { $0 + $1.size })
        )

        let html = String(
            decoding: TorrentPreviewHTMLRenderer.preview(
                for: metadata,
                sourceFileName: "large.torrent"
            ),
            as: UTF8.self
        )

        XCTAssertTrue(html.contains("file-249.bin"))
        XCTAssertFalse(html.contains("file-250.bin"))
        XCTAssertTrue(html.contains("Showing the first 250 files. 2 more are not shown."))
    }

    func testTorrentPreviewErrorEscapesFileNameAndMessage() {
        let html = String(
            decoding: TorrentPreviewHTMLRenderer.errorPreview(
                sourceFileName: "bad<&>.torrent",
                message: "Malformed <metadata> & data"
            ),
            as: UTF8.self
        )

        XCTAssertTrue(html.contains("bad&lt;&amp;&gt;.torrent"))
        XCTAssertTrue(html.contains("Malformed &lt;metadata&gt; &amp; data"))
    }

    func testLocalTorrentStrictlyDecodesBoundedSingleAndMultiFileMetadata() throws {
        let pieces = bencodedBytes(Data(repeating: 0xAB, count: 20))
        let single = torrentDocument(info: [
            "length": bencodedInteger(123),
            "name": bencodedString("single.txt"),
            "piece length": bencodedInteger(16_384),
            "pieces": pieces,
            "private": bencodedInteger(1)
        ])
        let singleTorrent = try LocalTorrent(validating: single)

        XCTAssertEqual(singleTorrent.name, "single.txt")
        XCTAssertEqual(singleTorrent.size, 123)
        XCTAssertEqual(singleTorrent.files, [.init(path: "single.txt", size: 123)])
        XCTAssertEqual(singleTorrent.isPrivate, true)

        let firstFile = bencodedDictionary([
            "length": bencodedInteger(10),
            "path": bencodedList([bencodedString("Folder"), bencodedString("one.txt")])
        ])
        let secondFile = bencodedDictionary([
            "length": bencodedInteger(20),
            "path.utf-8": bencodedList([bencodedString("Folder"), bencodedString("two.txt")])
        ])
        let multiple = torrentDocument(info: [
            "files": bencodedList([firstFile, secondFile]),
            "name.utf-8": bencodedString("Collection"),
            "piece length": bencodedInteger(16_384),
            "pieces": pieces
        ])
        let multiTorrent = try LocalTorrent(validating: multiple)

        XCTAssertEqual(multiTorrent.name, "Collection")
        XCTAssertEqual(multiTorrent.size, 30)
        XCTAssertEqual(
            multiTorrent.files,
            [
                .init(path: "Folder/one.txt", size: 10),
                .init(path: "Folder/two.txt", size: 20)
            ]
        )
        XCTAssertNil(multiTorrent.isPrivate)
    }

    func testLocalTorrentRejectsMalformedAndUnsupportedMetadata() {
        let pieces = bencodedBytes(Data(repeating: 0, count: 20))
        let malformedDocuments: [Data] = [
            Data(),
            Data("not bencode".utf8),
            Data("d4:infodejunk".utf8),
            Data("d4:infod4:name4:testee".utf8),
            Data("d4:infod6:lengthi-1e4:name4:test12:piece lengthi1e6:pieces20:00000000000000000000ee".utf8),
            Data("d4:infod6:lengthi1e4:name4:test12:piece lengthi1e6:pieces19:0000000000000000000ee".utf8),
            Data("d4:info1:a4:info1:bee".utf8),
            Data("d4:info-1:aee".utf8),
            Data("d4:info999999999999999999999:aee".utf8)
        ]

        for document in malformedDocuments {
            XCTAssertThrowsError(try LocalTorrent(validating: document))
        }

        let bothFileShapes = torrentDocument(info: [
            "files": bencodedList([]),
            "length": bencodedInteger(1),
            "name": bencodedString("test"),
            "piece length": bencodedInteger(1),
            "pieces": pieces
        ])
        XCTAssertThrowsError(try LocalTorrent(validating: bothFileShapes))
    }

    func testLocalTorrentRequiresExactPieceHashCount() throws {
        let zeroLength = torrentDocument(info: [
            "length": bencodedInteger(0),
            "name": bencodedString("empty"),
            "piece length": bencodedInteger(1),
            "pieces": bencodedBytes(Data())
        ])
        XCTAssertNoThrow(try LocalTorrent(validating: zeroLength))

        let missingHash = torrentDocument(info: [
            "length": bencodedInteger(2),
            "name": bencodedString("missing"),
            "piece length": bencodedInteger(1),
            "pieces": bencodedBytes(Data(repeating: 0, count: 20))
        ])
        let excessHash = torrentDocument(info: [
            "length": bencodedInteger(1),
            "name": bencodedString("excess"),
            "piece length": bencodedInteger(1),
            "pieces": bencodedBytes(Data(repeating: 0, count: 40))
        ])

        for document in [missingHash, excessHash] {
            XCTAssertThrowsError(try LocalTorrent(validating: document)) { error in
                XCTAssertEqual(error as? TorrentImportError, .malformedMetadata)
            }
        }
    }

    func testLocalTorrentEnforcesImportLimits() {
        let document = torrentDocument(info: [
            "length": bencodedInteger(1),
            "name": bencodedString("test"),
            "piece length": bencodedInteger(1),
            "pieces": bencodedBytes(Data(repeating: 0, count: 20))
        ])
        let sizeLimit = TorrentImportLimits(
            maximumEncodedBytes: document.count - 1,
            maximumDepth: 64,
            maximumNodes: 100_000,
            maximumFiles: 25_000,
            maximumPathComponents: 128,
            maximumTextBytes: 4_096
        )
        XCTAssertThrowsError(try LocalTorrent(validating: document, limits: sizeLimit)) { error in
            XCTAssertEqual(
                error as? TorrentImportError,
                .fileTooLarge(maximumBytes: sizeLimit.maximumEncodedBytes)
            )
        }

        let nodeLimit = TorrentImportLimits(
            maximumEncodedBytes: document.count,
            maximumDepth: 64,
            maximumNodes: 2,
            maximumFiles: 25_000,
            maximumPathComponents: 128,
            maximumTextBytes: 4_096
        )
        XCTAssertThrowsError(try LocalTorrent(validating: document, limits: nodeLimit)) { error in
            XCTAssertEqual(error as? TorrentImportError, .metadataLimitExceeded)
        }

        let textLimit = TorrentImportLimits(
            maximumEncodedBytes: document.count,
            maximumDepth: 64,
            maximumNodes: 100_000,
            maximumFiles: 25_000,
            maximumPathComponents: 128,
            maximumTextBytes: 3
        )
        XCTAssertThrowsError(try LocalTorrent(validating: document, limits: textLimit)) { error in
            XCTAssertEqual(error as? TorrentImportError, .metadataLimitExceeded)
        }
    }

    func testLocalTorrentRejectsDeterministicArbitraryByteCorpusWithoutTrapping() {
        var state: UInt64 = 0x5EED
        for length in 0..<512 {
            let bytes = (0..<length).map { _ -> UInt8 in
                state = state &* 6_364_136_223_846_793_005 &+ 1
                return UInt8(truncatingIfNeeded: state >> 24)
            }
            _ = try? LocalTorrent(validating: Data(bytes))
        }
    }

    func testTorrentActionIdentifiersIncludeServerIdentity() {
        let firstServerID = UUID()
        let first = TorrentActionIdentifier(
            serverID: firstServerID,
            torrentID: "1"
        )
        let duplicate = TorrentActionIdentifier(
            serverID: firstServerID,
            torrentID: "1"
        )
        let otherServer = TorrentActionIdentifier(
            serverID: UUID(),
            torrentID: "1"
        )

        XCTAssertEqual(first, duplicate)
        XCTAssertNotEqual(first, otherServer)
        XCTAssertEqual(Set([first, duplicate, otherServer]).count, 2)
    }

    func testServerDraftNormalizesFieldsAndCredentials() throws {
        let draft = try TemporaryServer(
            validatingName: "  Seedbox\n",
            endpoint: "  https://example.com/transmission/rpc  ",
            typeCode: ServerType.transmission.code,
            username: "  user  ",
            password: " password with spaces ",
            customHeaders: [
                .init(name: " X-Proxy-Token ", value: " secret value "),
                .init(name: " ", value: " ")
            ]
        )

        XCTAssertEqual(draft.name, "Seedbox")
        XCTAssertEqual(draft.endpoint.absoluteString, "https://example.com/transmission/rpc")
        XCTAssertEqual(draft.type, .transmission)
        XCTAssertEqual(
            draft.credentials,
            .init(username: "user", password: " password with spaces ")
        )
        XCTAssertEqual(draft.connectionDetails.credentials, draft.credentials)
        XCTAssertEqual(
            draft.customHeaders,
            [.init(name: "X-Proxy-Token", value: "secret value")]
        )
        XCTAssertEqual(draft.connectionDetails.customHeaders, draft.customHeaders)

        let anonymous = try TemporaryServer(
            validatingName: "Local",
            endpoint: "http://localhost:9091/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "  ",
            password: "\n"
        )
        XCTAssertNil(anonymous.credentials)
        XCTAssertTrue(anonymous.customHeaders.isEmpty)
    }

    func testServerDraftRejectsInvalidFieldsAndReportsTransportWarnings() {
        let invalid = TemporaryServer.validate(
            name: " ",
            endpoint: "seedbox.local",
            typeCode: 999,
            username: "user",
            password: ""
        )

        XCTAssertNotNil(invalid.nameError)
        XCTAssertNotNil(invalid.endpointError)
        XCTAssertNotNil(invalid.typeError)
        XCTAssertNotNil(invalid.credentialsError)
        XCTAssertFalse(invalid.isValid)

        XCTAssertThrowsError(
            try TemporaryServer(
                validatingName: "Seedbox",
                endpoint: "seedbox.local",
                typeCode: ServerType.transmission.code,
                username: "",
                password: ""
            )
        ) { error in
            XCTAssertEqual(error as? ServerPersistenceError, .invalidEndpoint)
        }
        XCTAssertThrowsError(
            try TemporaryServer(
                validatingName: "Seedbox",
                endpoint: "https://example.com/transmission/rpc",
                typeCode: ServerType.transmission.code,
                username: "user",
                password: ""
            )
        ) { error in
            XCTAssertEqual(error as? ServerPersistenceError, .incompleteCredentials)
        }

        let insecure = TemporaryServer.validate(
            name: "Seedbox",
            endpoint: "http://seedbox.local/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "",
            password: ""
        )
        XCTAssertTrue(insecure.isValid)
        XCTAssertNotNil(insecure.transportWarning)

        let secure = TemporaryServer.validate(
            name: "Seedbox",
            endpoint: "https://seedbox.example/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "",
            password: ""
        )
        XCTAssertTrue(secure.isValid)
        XCTAssertNil(secure.transportWarning)
    }

    func testServerDraftValidatesCustomHeaders() {
        func validation(
            _ customHeaders: [ConnectionDetails.CustomHeader]
        ) -> ServerDraftValidation {
            TemporaryServer.validate(
                name: "Seedbox",
                endpoint: "https://seedbox.example/transmission/rpc",
                typeCode: ServerType.transmission.code,
                username: "",
                password: "",
                customHeaders: customHeaders
            )
        }

        XCTAssertNotNil(validation([.init(name: "X-Token", value: "")]).customHeadersError)
        XCTAssertNotNil(validation([.init(name: "Invalid Header", value: "value")]).customHeadersError)
        XCTAssertNotNil(validation([
            .init(name: "X-Token", value: "one"),
            .init(name: "x-token", value: "two")
        ]).customHeadersError)
        XCTAssertNotNil(validation([
            .init(name: "X-Token", value: "secret\r\nInjected: value")
        ]).customHeadersError)
        XCTAssertNotNil(validation([
            .init(name: "X-Token", value: "secret\u{0}value")
        ]).customHeadersError)

        XCTAssertThrowsError(
            try TemporaryServer(
                validatingName: "Seedbox",
                endpoint: "https://seedbox.example/transmission/rpc",
                typeCode: ServerType.transmission.code,
                username: "",
                password: "",
                customHeaders: [.init(name: "X-Token", value: "")]
            )
        ) { error in
            guard case .invalidCustomHeaders = error as? ServerPersistenceError else {
                return XCTFail("Expected invalid custom headers, got \(error)")
            }
        }
    }

    func testServerDecodesLegacyRecordWithoutCustomHeaders() throws {
        let original = makeServer(
            credentials: .init(username: "user", password: "password"),
            customHeaders: [.init(name: "X-Proxy-Token", value: "secret")]
        )
        let encoded = try JSONEncoder().encode(original)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "customHeaders")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Server.self, from: legacyData)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.credentials, original.credentials)
        XCTAssertTrue(decoded.customHeaders.isEmpty)
    }

    func testCrossOriginRedirectStripsAuthenticationHeaders() {
        let details = ConnectionDetails(
            type: .transmission,
            endpoint: URL(string: "https://seedbox.example/transmission/rpc")!,
            credentials: .init(username: "user", password: "password"),
            customHeaders: [.init(name: "X-Proxy-Token", value: "secret")]
        )
        var proposedRequest = URLRequest(url: URL(string: "https://other.example/rpc")!)
        proposedRequest.setValue("secret", forHTTPHeaderField: "X-Proxy-Token")
        proposedRequest.setValue("Basic credentials", forHTTPHeaderField: "Authorization")
        proposedRequest.setValue("SID=session", forHTTPHeaderField: "Cookie")
        proposedRequest.setValue("csrf", forHTTPHeaderField: "X-Transmission-Session-Id")
        proposedRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let crossOrigin = details.redirectRequest(
            from: details.endpoint,
            proposedRequest: proposedRequest
        )
        XCTAssertNil(crossOrigin.value(forHTTPHeaderField: "X-Proxy-Token"))
        XCTAssertNil(crossOrigin.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNil(crossOrigin.value(forHTTPHeaderField: "Cookie"))
        XCTAssertNil(crossOrigin.value(forHTTPHeaderField: "X-Transmission-Session-Id"))
        XCTAssertEqual(crossOrigin.value(forHTTPHeaderField: "Accept"), "application/json")

        proposedRequest.url = URL(string: "https://seedbox.example:443/redirected")!
        let sameOrigin = details.redirectRequest(
            from: details.endpoint,
            proposedRequest: proposedRequest
        )
        XCTAssertEqual(sameOrigin.value(forHTTPHeaderField: "X-Proxy-Token"), "secret")
        XCTAssertEqual(sameOrigin.value(forHTTPHeaderField: "Authorization"), "Basic credentials")
    }

    func testServerPreservesIdentityDisplayHostAndConnectionDetails() {
        let id = UUID()
        let credentials = ConnectionDetails.Credentials(username: "user", password: "password")
        let customHeaders = [ConnectionDetails.CustomHeader(name: "X-Proxy-Token", value: "secret")]
        let server = makeServer(
            id: id,
            endpoint: "https://url-user:url-password@example.com:8443/private?token=secret",
            name: "Primary",
            type: .qBittorrent,
            credentials: credentials,
            customHeaders: customHeaders
        )
        let otherIdentity = makeServer(
            endpoint: server.endpoint.absoluteString,
            name: server.name,
            type: .qBittorrent,
            credentials: credentials,
            customHeaders: customHeaders
        )

        XCTAssertEqual(server.id, id)
        XCTAssertNotEqual(server, otherIdentity)
        XCTAssertEqual(Set([server, otherIdentity]).count, 2)
        XCTAssertEqual(server.displayHost, "example.com:8443")
        XCTAssertFalse(server.displayHost.contains("password"))
        XCTAssertFalse(server.displayHost.contains("token"))
        XCTAssertEqual(server.connectionDetails.type, .qBittorrent)
        XCTAssertEqual(server.connectionDetails.endpoint, server.endpoint)
        XCTAssertEqual(server.connectionDetails.credentials, credentials)
        XCTAssertEqual(server.connectionDetails.customHeaders, customHeaders)
    }

    @MainActor
    func testRepositoryRefreshSortsLooksUpAndRetainsPublishedServersOnReadFailure() {
        let stale = makeServer(name: "Stale")
        let alpha = makeServer(name: "alpha")
        let zulu = makeServer(name: "Zulu")
        let store = InMemoryServerStore(servers: [zulu, alpha])
        let repository = ServerRepository(
            store: store,
            initialServers: [stale]
        )

        repository.refresh()

        XCTAssertEqual(repository.servers.map(\.name), ["alpha", "Zulu"])
        XCTAssertEqual(repository.server(id: alpha.id), alpha)
        XCTAssertNil(repository.server(id: stale.id))
        XCTAssertNil(repository.errorMessage)

        store.readError = TestServerStoreError.read
        store.values = [:]
        repository.refresh()

        XCTAssertEqual(repository.servers, [alpha, zulu])
        XCTAssertEqual(repository.errorMessage, TestServerStoreError.read.localizedDescription)

        store.readError = nil
        repository.refresh()
        XCTAssertTrue(repository.servers.isEmpty)
        XCTAssertNil(repository.errorMessage)
    }

    @MainActor
    func testRepositoryHappyPathCRUDUpdatesWholeRecords() throws {
        let store = InMemoryServerStore()
        let repository = ServerRepository(store: store)
        let zuluDraft = try TemporaryServer(
            validatingName: "Zulu",
            endpoint: "https://zulu.example/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "user",
            password: "password"
        )
        let alphaDraft = try TemporaryServer(
            validatingName: "Alpha",
            endpoint: "https://alpha.example/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "",
            password: ""
        )

        let zulu = try repository.insert(zuluDraft)
        let alpha = try repository.insert(alphaDraft)
        XCTAssertEqual(repository.servers.map(\.id), [alpha.id, zulu.id])
        XCTAssertEqual(store.values[zulu.id], zulu)
        XCTAssertEqual(store.setCalls, [zulu, alpha])

        let updatedDraft = try TemporaryServer(
            validatingName: "Bravo",
            endpoint: "https://bravo.example/qbittorrent",
            typeCode: ServerType.qBittorrent.code,
            username: "new-user",
            password: "new-password",
            customHeaders: [.init(name: "X-Proxy-Token", value: "secret")]
        )
        let updated = try repository.update(id: zulu.id, with: updatedDraft)

        XCTAssertEqual(updated.id, zulu.id)
        XCTAssertEqual(updated.name, "Bravo")
        XCTAssertEqual(updated.credentials, .init(username: "new-user", password: "new-password"))
        XCTAssertEqual(
            updated.customHeaders,
            [.init(name: "X-Proxy-Token", value: "secret")]
        )
        XCTAssertEqual(repository.servers.map(\.name), ["Alpha", "Bravo"])
        XCTAssertEqual(store.values[zulu.id], updated)

        try repository.delete(id: alpha.id)
        XCTAssertEqual(repository.servers, [updated])
        XCTAssertNil(store.values[alpha.id])
        XCTAssertEqual(store.removeCalls, [alpha.id])
    }

    @MainActor
    func testRepositoryRejectsDuplicateAndMissingUpdatesWithoutWrites() throws {
        let first = makeServer(name: "First")
        let second = makeServer(name: "Second")
        let store = InMemoryServerStore(servers: [first, second])
        let repository = ServerRepository(
            store: store,
            initialServers: [first, second]
        )
        let duplicate = try TemporaryServer(
            validatingName: " second ",
            endpoint: "https://changed.example/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "",
            password: ""
        )
        let unique = try TemporaryServer(
            validatingName: "Unique",
            endpoint: "https://unique.example/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "",
            password: ""
        )

        XCTAssertThrowsError(try repository.insert(duplicate)) { error in
            XCTAssertEqual(error as? ServerPersistenceError, .duplicateName)
        }
        XCTAssertThrowsError(try repository.update(id: first.id, with: duplicate)) { error in
            XCTAssertEqual(error as? ServerPersistenceError, .duplicateName)
        }
        XCTAssertThrowsError(try repository.update(id: UUID(), with: unique)) { error in
            guard let persistenceError = error as? ServerPersistenceError,
                  case .persistence = persistenceError else {
                return XCTFail("Expected a missing-server persistence error, got \(error)")
            }
        }

        XCTAssertTrue(store.setCalls.isEmpty)
        XCTAssertEqual(repository.servers, [first, second])
        XCTAssertEqual(store.values, [first.id: first, second.id: second])
    }

    @MainActor
    func testRepositoryStoreFailuresPreservePublishedState() throws {
        let original = makeServer(name: "Original")
        let store = InMemoryServerStore(servers: [original])
        let repository = ServerRepository(
            store: store,
            initialServers: [original]
        )
        let draft = try TemporaryServer(
            validatingName: "Updated",
            endpoint: "https://updated.example/transmission/rpc",
            typeCode: ServerType.transmission.code,
            username: "",
            password: ""
        )

        store.setError = TestServerStoreError.write
        XCTAssertThrowsError(try repository.insert(draft))
        XCTAssertEqual(repository.servers, [original])
        XCTAssertThrowsError(try repository.update(id: original.id, with: draft))
        XCTAssertEqual(repository.servers, [original])
        XCTAssertEqual(store.values, [original.id: original])

        store.setError = nil
        store.removeError = TestServerStoreError.remove
        XCTAssertThrowsError(try repository.delete(id: original.id))
        XCTAssertEqual(repository.servers, [original])
        XCTAssertEqual(store.values, [original.id: original])
    }

    @MainActor
    func testSettingsPresenterDeletionFlow() {
        let server = makeServer()
        let store = InMemoryServerStore(servers: [server])
        let repository = ServerRepository(
            store: store,
            initialServers: [server]
        )
        let presenter = SettingsPresenter(repository: repository)

        presenter.perform(.delete(server))
        XCTAssertTrue(presenter.showingDeleteAlert)
        XCTAssertEqual(presenter.serverUnderModification, server)

        presenter.perform(.abortDeletion)
        XCTAssertFalse(presenter.showingDeleteAlert)
        XCTAssertNil(presenter.serverUnderModification)
        XCTAssertEqual(repository.servers, [server])

        presenter.perform(.delete(server))
        presenter.perform(.confirmDeletion)
        XCTAssertFalse(presenter.showingDeleteAlert)
        XCTAssertNil(presenter.serverUnderModification)
        XCTAssertNil(presenter.persistenceError)
        XCTAssertTrue(repository.servers.isEmpty)
        XCTAssertEqual(store.removeCalls, [server.id])
    }

    @MainActor
    func testSettingsPresenterReportsDeletionFailureWithoutRemovingServer() {
        let server = makeServer()
        let store = InMemoryServerStore(servers: [server])
        store.removeError = TestServerStoreError.remove
        let repository = ServerRepository(
            store: store,
            initialServers: [server]
        )
        let presenter = SettingsPresenter(repository: repository)

        presenter.perform(.delete(server))
        presenter.perform(.confirmDeletion)

        XCTAssertEqual(presenter.persistenceError, TestServerStoreError.remove.localizedDescription)
        XCTAssertFalse(presenter.persistenceErrorIsCleanupWarning)
        XCTAssertEqual(repository.servers, [server])
        XCTAssertEqual(store.values, [server.id: server])
        XCTAssertEqual(store.removeCalls, [server.id])
    }

    @MainActor
    func testServerEditorRetainsInsertedIdentityForSubsequentUpdates() async throws {
        let store = InMemoryServerStore()
        let repository = ServerRepository(store: store)
        let model = ServerEditorModel(repository: repository)
        model.name = "Seedbox"
        model.endpoint = "http://seedbox.local/transmission/rpc"
        model.username = "user"
        model.password = "password"
        model.customHeaders = [
            ServerEditorHeader(name: " X-Proxy-Token ", value: " secret ")
        ]

        let firstSaveSucceeded = await model.save()
        XCTAssertTrue(firstSaveSucceeded)
        let insertedID = try XCTUnwrap(model.server?.id)
        XCTAssertEqual(repository.servers.count, 1)
        XCTAssertNil(model.validation.nameError)
        XCTAssertEqual(
            model.server?.customHeaders,
            [.init(name: "X-Proxy-Token", value: "secret")]
        )

        model.endpoint = "https://updated.example/transmission/rpc"
        model.fieldsChanged()
        let secondSaveSucceeded = await model.save()
        XCTAssertTrue(secondSaveSucceeded)

        XCTAssertEqual(model.server?.id, insertedID)
        XCTAssertEqual(repository.servers.map(\.id), [insertedID])
        XCTAssertEqual(repository.servers.first?.endpoint.absoluteString, model.endpoint)
        XCTAssertEqual(store.setCalls.count, 2)
    }

    @MainActor
    func testServerEditorSuppressesRepeatedConnectionTests() async {
        let tester = ControlledServerConnectionTester()
        let model = ServerEditorModel(
            repository: ServerRepository(store: InMemoryServerStore()),
            connectionTester: tester
        )
        model.name = "Seedbox"
        model.endpoint = "http://seedbox.local/transmission/rpc"
        model.customHeaders = [
            ServerEditorHeader(name: " X-Proxy-Token ", value: " secret ")
        ]

        let firstTest = Task { @MainActor in
            await model.testConnection()
        }
        while await tester.callCount == 0 {
            await Task.yield()
        }

        XCTAssertEqual(model.operationState, .testing)
        let receivedHeaders = await tester.receivedDetails?.customHeaders
        XCTAssertEqual(
            receivedHeaders,
            [.init(name: "X-Proxy-Token", value: "secret")]
        )
        await model.testConnection()
        let callCount = await tester.callCount
        XCTAssertEqual(callCount, 1)

        await tester.succeed()
        await firstTest.value
        XCTAssertEqual(
            model.operationState,
            .success("Connection established successfully.")
        )
    }

    @MainActor
    func testServerEditorRemovesCustomHeaderByIdentity() {
        let model = ServerEditorModel(
            repository: ServerRepository(store: InMemoryServerStore())
        )
        model.addCustomHeader()
        model.addCustomHeader()
        model.customHeaders[0].name = "X-First"
        model.customHeaders[1].name = "X-Second"
        let firstID = model.customHeaders[0].id
        let secondID = model.customHeaders[1].id

        model.removeCustomHeader(id: firstID)

        XCTAssertEqual(model.customHeaders.map(\.id), [secondID])
        XCTAssertEqual(model.customHeaders.map(\.name), ["X-Second"])
    }

    @MainActor
    func testServerEditorIgnoresStaleConnectionResultAfterFieldChange() async {
        let tester = ControlledServerConnectionTester()
        let model = ServerEditorModel(
            repository: ServerRepository(store: InMemoryServerStore()),
            connectionTester: tester
        )
        model.name = "Seedbox"
        model.endpoint = "http://seedbox.local/transmission/rpc"

        let testTask = Task { @MainActor in
            await model.testConnection()
        }
        while await tester.callCount == 0 {
            await Task.yield()
        }

        model.endpoint = "http://changed.local/transmission/rpc"
        model.fieldsChanged()
        await tester.succeed()
        await testTask.value

        XCTAssertEqual(model.operationState, .idle)
    }

    @MainActor
    func testServerEditorSuggestsRecoveryForLocalNetworkFailure() async {
        let tester = ControlledServerConnectionTester()
        let model = ServerEditorModel(
            repository: ServerRepository(store: InMemoryServerStore()),
            connectionTester: tester
        )
        model.name = "Seedbox"
        model.endpoint = "http://seedbox.local/transmission/rpc"

        let testTask = Task { @MainActor in
            await model.testConnection()
        }
        while await tester.callCount == 0 {
            await Task.yield()
        }
        await tester.fail(with: ServerCommunicationError.connectivity(.localNetworkUnavailable))
        await testTask.value

        XCTAssertTrue(model.suggestsLocalNetworkRecovery)
        XCTAssertEqual(
            model.operationState,
            .failure(ServerCommunicationError.connectivity(.localNetworkUnavailable).localizedDescription)
        )
    }

    @MainActor
    func testServerEditorClearsLocalNetworkRecoveryBeforeFailedSave() async {
        let store = InMemoryServerStore()
        store.setError = TestServerStoreError.write
        let tester = ControlledServerConnectionTester()
        let model = ServerEditorModel(
            repository: ServerRepository(store: store),
            connectionTester: tester
        )
        model.name = "Seedbox"
        model.endpoint = "http://seedbox.local/transmission/rpc"

        let testTask = Task { @MainActor in
            await model.testConnection()
        }
        while await tester.callCount == 0 {
            await Task.yield()
        }
        await tester.fail(with: ServerCommunicationError.connectivity(.localNetworkUnavailable))
        await testTask.value
        XCTAssertTrue(model.suggestsLocalNetworkRecovery)

        let saveSucceeded = await model.save()
        XCTAssertFalse(saveSucceeded)
        XCTAssertFalse(model.suggestsLocalNetworkRecovery)
        XCTAssertTrue(store.values.isEmpty)
    }

    func testLocalNetworkEndpointClassification() throws {
        let localEndpoints = [
            "http://localhost:9091",
            "http://seedbox.local/transmission/rpc",
            "http://seedbox.local./transmission/rpc",
            "http://seedbox.lan/transmission/rpc",
            "http://seedbox.home.arpa/transmission/rpc",
            "http://seedbox:9091/transmission/rpc",
            "http://127.0.0.1",
            "http://10.0.0.4",
            "http://172.16.1.2",
            "http://172.31.255.254",
            "http://192.168.1.10",
            "http://169.254.1.1",
            "http://[::1]",
            "http://[fe80::1]",
            "http://[fe90::1]",
            "http://[febf::1]",
            "http://[fd00::1]"
        ]
        for endpoint in localEndpoints {
            XCTAssertTrue(try XCTUnwrap(URL(string: endpoint)).isLocalNetworkEndpoint, endpoint)
        }

        let publicEndpoints = [
            "https://example.com",
            "http://172.15.1.2",
            "http://172.32.1.2",
            "http://192.167.1.10",
            "http://10.0.0.1.example",
            "http://192.168.1.example",
            "http://[fec0::1]",
            "http://fc.example.com"
        ]
        for endpoint in publicEndpoints {
            XCTAssertFalse(try XCTUnwrap(URL(string: endpoint)).isLocalNetworkEndpoint, endpoint)
        }
    }

    func testConnectivityErrorClassificationUsesEndpointContext() throws {
        let timeout = URLError(.timedOut)
        let localEndpoint = try XCTUnwrap(URL(string: "http://seedbox.local"))
        let publicEndpoint = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertEqual(
            ServerCommunicationError.connectivity(timeout, endpoint: localEndpoint),
            .connectivity(.localNetworkTimedOut)
        )
        XCTAssertEqual(
            ServerCommunicationError.connectivity(timeout, endpoint: publicEndpoint),
            .connectivity(.timedOut)
        )
        XCTAssertEqual(
            ServerCommunicationError.connectivity(
                URLError(.cannotConnectToHost),
                endpoint: localEndpoint
            ),
            .connectivity(.connectionRefused)
        )
        XCTAssertEqual(
            ServerCommunicationError.connectivity(
                URLError(.notConnectedToInternet),
                endpoint: localEndpoint
            ),
            .connectivity(.localNetworkUnavailable)
        )
        XCTAssertEqual(
            ServerCommunicationError.connectivity(
                URLError(.notConnectedToInternet),
                endpoint: publicEndpoint
            ),
            .connectivity(.offline)
        )
        XCTAssertEqual(
            ServerCommunicationError.connectivity(
                URLError(.networkConnectionLost),
                endpoint: publicEndpoint
            ),
            .connectivity(.connectionLost)
        )
        XCTAssertTrue(
            ServerCommunicationError.connectivity(timeout, endpoint: localEndpoint)
                .suggestsLocalNetworkRecovery
        )
    }

    @MainActor
    func testSpeedLimitPresenterValidatesAndAppliesChangesAtomically() async {
        let server = makeServer(endpoint: "http://seedbox.local/transmission/rpc")
        let connection = ControlledSpeedLimitConnection()
        let presenter = RemoteServerSettingsPresenter(server: server, connection: connection)

        while presenter.isLoading {
            await Task.yield()
        }

        presenter.speedLimitConfiguration.down = -1
        presenter.applyChanges()
        await Task.yield()
        let invalidSetCallCount = await connection.setCallCount
        XCTAssertFalse(presenter.hasValidSpeedLimits)
        XCTAssertEqual(invalidSetCallCount, 0)

        presenter.speedLimitConfiguration.down = 1_000
        presenter.speedLimitConfiguration.up = 500
        presenter.speedLimitState.down = true
        presenter.applyChanges()
        while await connection.setCallCount == 0 {
            await Task.yield()
        }
        presenter.applyChanges()
        let setCallCount = await connection.setCallCount
        let receivedLimits = await connection.receivedLimits
        let receivedEnabled = await connection.receivedEnabled

        XCTAssertTrue(presenter.isSaving)
        XCTAssertEqual(setCallCount, 1)
        XCTAssertEqual(receivedLimits?.down, 1_000)
        XCTAssertEqual(receivedLimits?.up, 500)
        XCTAssertEqual(receivedEnabled?.down, true)
        XCTAssertEqual(receivedEnabled?.up, false)

        await connection.succeedSet()
        while presenter.isSaving || presenter.isLoading {
            await Task.yield()
        }

        XCTAssertFalse(presenter.isErrored)
        XCTAssertFalse(presenter.hasChanges)
        XCTAssertEqual(presenter.speedLimitConfiguration.down, 1_000)
        XCTAssertEqual(presenter.speedLimitConfiguration.up, 500)
        XCTAssertTrue(presenter.speedLimitState.down)
        XCTAssertFalse(presenter.speedLimitState.up)
    }

    @MainActor
    func testSpeedLimitPresenterPreservesUneditedByteValues() async {
        let server = makeServer(endpoint: "http://seedbox.local/transmission/rpc")
        let original = GlobalSpeedLimits(
            download: .init(bytesPerSecond: 500, isEnabled: true),
            upload: .init(bytesPerSecond: 524_288, isEnabled: false)
        )
        let connection = ControlledSpeedLimitConnection(limits: original)
        let presenter = RemoteServerSettingsPresenter(server: server, connection: connection)

        while presenter.isLoading {
            await Task.yield()
        }
        XCTAssertEqual(presenter.speedLimitConfiguration.down, 1)
        presenter.speedLimitState.up = true
        presenter.applyChanges()
        while await connection.setCallCount == 0 {
            await Task.yield()
        }

        let received = await connection.receivedGlobalLimits
        XCTAssertEqual(received?.download.bytesPerSecond, original.download.bytesPerSecond)
        XCTAssertEqual(received?.upload.bytesPerSecond, original.upload.bytesPerSecond)

        await connection.succeedSet()
        while presenter.isSaving {
            await Task.yield()
        }
    }

    @MainActor
    func testKeychainServerStoreWholeRecordCRUDRoundTrip() throws {
        let store = KeychainServerStore(
            service: "io.edr.seedtruck.tests.servers.\(UUID().uuidString)"
        )
        let id = UUID()
        defer {
            try? store.removeServer(id: id)
        }

        XCTAssertTrue(try store.servers().isEmpty)

        let initial = makeServer(
            id: id,
            endpoint: "https://example.com/transmission/rpc",
            name: "Initial",
            credentials: .init(username: "user", password: "password"),
            customHeaders: [.init(name: "X-Proxy-Token", value: "initial-secret")]
        )
        try store.set(initial)
        XCTAssertEqual(try store.servers(), [initial])

        let updated = makeServer(
            id: id,
            endpoint: "https://example.com/qbittorrent",
            name: "Updated",
            type: .qBittorrent,
            credentials: .init(username: "other", password: "updated"),
            customHeaders: [.init(name: "X-Proxy-Token", value: "updated-secret")]
        )
        try store.set(updated)
        XCTAssertEqual(try store.servers(), [updated])

        try store.removeServer(id: id)
        XCTAssertTrue(try store.servers().isEmpty)
    }

    @MainActor
    func testConnectionStoreEvictsConnection() {
        let serverID = UUID()
        let details = ConnectionDetails(
            type: .transmission,
            endpoint: URL(string: "https://example.com/transmission/rpc")!,
            credentials: nil
        )
        let first = ServerConnectionStore.shared.connection(for: serverID, details: details)
        let retained = ServerConnectionStore.shared.connection(for: serverID, details: details)

        XCTAssertTrue((first as AnyObject) === (retained as AnyObject))

        ServerConnectionStore.shared.removeConnection(for: serverID)
        let replacement = ServerConnectionStore.shared.connection(for: serverID, details: details)

        XCTAssertFalse((first as AnyObject) === (replacement as AnyObject))
        ServerConnectionStore.shared.removeConnection(for: serverID)
    }

    @MainActor
    func testConnectionStoreReplacesAdapterWhenClientTypeChanges() {
        let store = ServerConnectionStore(builder: TorrentClientRegistry.live)
        let serverID = UUID()
        let transmission = store.connection(
            for: serverID,
            details: .init(
                type: .transmission,
                endpoint: URL(string: "https://example.com/transmission/rpc")!,
                credentials: nil
            )
        )
        let qbittorrent = store.connection(
            for: serverID,
            details: .init(
                type: .qBittorrent,
                endpoint: URL(string: "https://example.com/qbittorrent")!,
                credentials: nil
            )
        )

        XCTAssertTrue(transmission is TransmissionConnection)
        XCTAssertTrue(qbittorrent is QBittorrentConnection)
        XCTAssertFalse((transmission as AnyObject) === (qbittorrent as AnyObject))
    }

    @MainActor
    func testConnectionStoreReplacesAdapterWhenCustomHeadersChange() {
        let store = ServerConnectionStore(builder: TorrentClientRegistry.live)
        let serverID = UUID()
        let endpoint = URL(string: "https://example.com/transmission/rpc")!
        let first = store.connection(
            for: serverID,
            details: .init(
                type: .transmission,
                endpoint: endpoint,
                credentials: nil,
                customHeaders: [.init(name: "X-Proxy-Token", value: "one")]
            )
        )
        let replacement = store.connection(
            for: serverID,
            details: .init(
                type: .transmission,
                endpoint: endpoint,
                credentials: nil,
                customHeaders: [.init(name: "X-Proxy-Token", value: "two")]
            )
        )

        XCTAssertFalse((first as AnyObject) === (replacement as AnyObject))
    }

    func testTorrentClientRegistryIsTheSingleSupportedClientCatalog() {
        let registry = TorrentClientRegistry.live

        XCTAssertEqual(registry.descriptors.map(\.id), [.transmission, .qBittorrent])
        XCTAssertEqual(registry.descriptor(for: .transmission)?.displayName, "Transmission")
        XCTAssertEqual(registry.descriptor(for: .qBittorrent)?.displayName, "qBittorrent")

        let details = ConnectionDetails(
            type: .qBittorrent,
            endpoint: URL(string: "https://example.com/qbittorrent")!,
            credentials: nil
        )
        XCTAssertTrue(registry.makeConnection(for: details) is QBittorrentConnection)
    }

    func testUnknownPersistedClientNeverFallsBackToTransmission() async {
        let unknownType = ServerType(rawValue: 99)
        let connection = TorrentClientRegistry.live.makeConnection(
            for: .init(
                type: unknownType,
                endpoint: URL(string: "https://example.com")!,
                credentials: nil
            )
        )

        XCTAssertTrue(connection is UnavailableServerConnection)
        do {
            _ = try await connection.getTorrents()
            XCTFail("Expected unsupported client error")
        } catch {
            XCTAssertEqual(error as? ServerCommunicationError, .unsupportedServerType(99))
        }
    }

    func testClientEndpointMetadataSupportsReverseProxiesAndRejectsAPIPaths() throws {
        let descriptor = try XCTUnwrap(
            TorrentClientRegistry.live.descriptor(for: .qBittorrent)
        )

        XCTAssertNil(
            descriptor.endpoint.validationError(
                for: URL(string: "https://example.com/services/qbittorrent")!
            )
        )
        XCTAssertNotNil(
            descriptor.endpoint.validationError(
                for: URL(string: "https://example.com/services/qbittorrent/api/v2")!
            )
        )
    }

    @MainActor
    func testQbittorrentTypePersistsThroughRepositoryConnectionDetails() throws {
        let store = InMemoryServerStore()
        let repository = ServerRepository(store: store)
        let draft = try TemporaryServer(
            validatingName: "qBittorrent",
            endpoint: "https://example.com/qbittorrent",
            typeCode: ServerType.qBittorrent.code,
            username: "user",
            password: "password"
        )
        let server = try repository.insert(draft)

        XCTAssertEqual(repository.server(id: server.id), server)
        XCTAssertEqual(store.values[server.id], server)
        XCTAssertEqual(server.type, ServerType.qBittorrent.rawValue)
        XCTAssertEqual(server.connectionDetails.type, .qBittorrent)
        XCTAssertEqual(
            server.connectionDetails.credentials,
            .init(username: "user", password: "password")
        )
    }
}

private enum TestServerStoreError: LocalizedError {

    case read
    case write
    case remove

    var errorDescription: String? {
        switch self {
        case .read:
            return "Test server read failed."
        case .write:
            return "Test server write failed."
        case .remove:
            return "Test server removal failed."
        }
    }
}

@MainActor
private final class InMemoryServerStore: ServerStoring {

    var values: [UUID: Server]
    var setCalls: [Server] = []
    var removeCalls: [UUID] = []
    var readError: Error?
    var setError: Error?
    var removeError: Error?

    init(servers: [Server] = []) {
        values = Dictionary(uniqueKeysWithValues: servers.map { ($0.id, $0) })
    }

    func servers() throws -> [Server] {
        if let readError {
            throw readError
        }
        return Array(values.values)
    }

    func set(_ server: Server) throws {
        setCalls.append(server)
        if let setError {
            throw setError
        }
        values[server.id] = server
    }

    func removeServer(id: UUID) throws {
        removeCalls.append(id)
        if let removeError {
            throw removeError
        }
        values[id] = nil
    }
}

private actor ControlledServerConnectionTester: ServerConnectionTesting {

    private(set) var callCount = 0
    private(set) var receivedDetails: ConnectionDetails?
    private var continuation: CheckedContinuation<Void, Error>?

    func checkConnection(using details: ConnectionDetails) async throws {
        callCount += 1
        receivedDetails = details
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed() {
        continuation?.resume()
        continuation = nil
    }

    func fail(with error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private actor ControlledSpeedLimitConnection: ServerConnection, GlobalSpeedLimitSupporting {

    private(set) var setCallCount = 0
    private(set) var receivedLimits: (down: Int, up: Int)?
    private(set) var receivedEnabled: (down: Bool, up: Bool)?
    private(set) var receivedGlobalLimits: GlobalSpeedLimits?
    private var limits: GlobalSpeedLimits
    private var setContinuation: CheckedContinuation<Void, Error>?

    init(
        limits: GlobalSpeedLimits = .init(
            download: .init(bytesPerSecond: 100_000, isEnabled: false),
            upload: .init(bytesPerSecond: 50_000, isEnabled: false)
        )
    ) {
        self.limits = limits
    }

    func checkConnection() async throws {}

    func addTorrent(_ request: TorrentAddRequest) async throws {
        throw ServerCommunicationError.notImplemented
    }

    func getTorrent(id: String) async throws -> RemoteTorrent {
        throw ServerCommunicationError.notImplemented
    }

    func getTorrents() async throws -> [RemoteTorrent] {
        []
    }

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws {
        throw ServerCommunicationError.notImplemented
    }

    func globalSpeedLimits() async throws -> GlobalSpeedLimits {
        limits
    }

    func setGlobalSpeedLimits(_ limits: GlobalSpeedLimits) async throws {
        setCallCount += 1
        receivedGlobalLimits = limits
        receivedLimits = (
            down: Int(limits.download.bytesPerSecond / 1_000),
            up: Int(limits.upload.bytesPerSecond / 1_000)
        )
        receivedEnabled = (
            down: limits.download.isEnabled,
            up: limits.upload.isEnabled
        )
        try await withCheckedThrowingContinuation { continuation in
            setContinuation = continuation
        }
        self.limits = limits
    }

    func succeedSet() {
        setContinuation?.resume()
        setContinuation = nil
    }
}
