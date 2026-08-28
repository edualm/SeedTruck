//
//  QBittorrentModelTests.swift
//  Tests iOS
//

import XCTest
@testable import SeedTruck

final class QBittorrentModelTests: XCTestCase {

    func testMapsTorrentFieldsTagsAndStatistics() throws {
        let torrent = try mappedTorrent(
            state: "downloading",
            overrides: """
                "tags": "Archive, Linux, Archive,  ",
                "dlspeed": 2048,
                "upspeed": 512,
                "downloaded": 4000,
                "uploaded": 1000,
                "ratio": 0.25,
                "eta": 120,
                "num_seeds": 3,
                "num_leechs": 2,
                "time_active": 300,
                "seeding_time": 50,
                "priority": 2,
            """
        )

        XCTAssertEqual(torrent.id, "abcdef")
        XCTAssertEqual(torrent.labels, ["Archive", "Linux"])
        XCTAssertEqual(torrent.status, .downloading)
        XCTAssertEqual(torrent.statistics.peersConnected, 5)
        XCTAssertEqual(torrent.statistics.downloadingFrom, 3)
        XCTAssertEqual(torrent.statistics.uploadingTo, 2)
        XCTAssertEqual(torrent.statistics.downloadRate, 2_048)
        XCTAssertEqual(torrent.statistics.uploadRate, 512)
        XCTAssertEqual(torrent.statistics.secondsDownloading, 250)
        XCTAssertEqual(torrent.statistics.secondsSeeding, 50)
        XCTAssertEqual(torrent.statistics.queuePosition, 1)
    }

    func testMapsAllSupportedStateFamiliesAndPreservesUnknownState() throws {
        let expectations: [(String, RemoteTorrent.Status)] = [
            ("stoppedDL", .stopped),
            ("stoppedUP", .stopped),
            ("pausedDL", .stopped),
            ("checkingResumeData", .queuedForCheck),
            ("checkingDL", .checking),
            ("queuedDL", .queuedForDownload),
            ("metaDL", .downloading),
            ("forcedMetaDL", .downloading),
            ("stalledDL", .downloading),
            ("moving", .downloading),
            ("queuedUP", .queuedForSeed),
            ("stalledUP", .seeding),
            ("forcedUP", .seeding),
            ("missingFiles", .unknown("missingFiles")),
            ("futureState", .unknown("futureState"))
        ]

        for (state, expected) in expectations {
            XCTAssertEqual(try mappedTorrent(state: state).status, expected)
        }
    }

    func testNormalizesInfiniteRatioAndUnknownETA() throws {
        let torrent = try mappedTorrent(
            state: "queuedDL",
            overrides: """
                "ratio": 9999,
                "eta": 8640000,
            """
        )

        XCTAssertEqual(torrent.statistics.uploadRatio, -2)
        XCTAssertEqual(torrent.statistics.eta, -2)
        XCTAssertEqual(TorrentDetailProjection(torrent: torrent).etaText, "Unknown")
    }

    func testRejectsIncompleteTorrentResponses() throws {
        let data = Data(#"{"name":"Missing hash","progress":0.5,"state":"downloading","size":100}"#.utf8)
        let decoder = JSONDecoder()
        let value = try decoder.decode(QBittorrent.Torrent.self, from: data)

        XCTAssertNil(RemoteTorrent(from: value))
    }

    private func mappedTorrent(
        state: String,
        overrides: String = ""
    ) throws -> RemoteTorrent {
        let data = Data("""
        {
            "hash": "abcdef",
            "name": "Fixture",
            "progress": 0.5,
            "state": "\(state)",
            "size": 10000,
            \(overrides)
            "added_on": 0
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let value = try decoder.decode(QBittorrent.Torrent.self, from: data)
        return try XCTUnwrap(RemoteTorrent(from: value))
    }
}
