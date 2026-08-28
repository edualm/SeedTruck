//
//  PreviewMockData.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

@MainActor
enum PreviewMockData {

    static let servers: [Server] = [
        Server(
            endpoint: URL(string: "http://seedbox.local:9091/transmission/rpc")!,
            name: "Home Seedbox",
            type: ServerType.transmission.rawValue
        ),
        Server(
            endpoint: URL(string: "https://archive.example.com/transmission/rpc")!,
            name: "Remote Archive",
            type: ServerType.transmission.rawValue
        ),
        Server(
            endpoint: URL(string: "https://downloads.example.com/qbittorrent")!,
            name: "qBittorrent",
            type: ServerType.qBittorrent.rawValue
        )
    ]

    static var settingsServer: Server? { servers.first }

    static var serverRepository: ServerRepository {
        ServerRepository(initialServers: servers)
    }
    
    #if os(iOS) || os(macOS)
    
    static let localTorrentMagnet: LocalTorrent = .magnet("magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Fexplodie.org%3A6969&tr=udp%3A%2F%2Ftracker.coppersurfer.tk%3A6969&tr=udp%3A%2F%2Ftracker.empire-js.us%3A1337&tr=udp%3A%2F%2Ftracker.leechers-paradise.org%3A6969&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337&tr=wss%3A%2F%2Ftracker.btorrent.xyz&tr=wss%3A%2F%2Ftracker.fastcast.nz&tr=wss%3A%2F%2Ftracker.openwebtorrent.com&ws=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2F&xs=https%3A%2F%2Fwebtorrent.io%2Ftorrents%2Fbig-buck-bunny.torrent", labels: ["Movies"])

    static let localTorrentFile: LocalTorrent = .torrent(
        data: Data(),
        metadata: .init(
            name: "BigBuckBunny_124_archive",
            isPrivate: false,
            files: (1 ... 12).map {
                .init(path: "BigBuckBunny_124/file-\($0).mp4", size: 35_075_000)
            },
            totalSize: 420_900_000
        )
    )
    
    #endif
    
    static let remoteTorrent = RemoteTorrent(
        id: "1",
        name: "Big Buck Bunny 4K HDR release with a long descriptive torrent name",
        progress: 0.58,
        status: .downloading,
        size: 8_400_000_000,
        labels: ["Movies", "Open source"],
        statistics: .init(
            peersConnected: 24,
            downloadingFrom: 8,
            uploadingTo: 3,
            downloadRate: 2_448_765,
            uploadRate: 125_000,
            uploadedEver: 1_250_000_000,
            downloadedEver: 4_872_000_000,
            uploadRatio: 0.26,
            eta: 1_845,
            secondsDownloading: 7_200,
            queuePosition: 0
        )
    )

    static let remoteTorrents = [
        RemoteTorrent(
            id: "stopped",
            name: "Stopped incomplete archive",
            progress: 0.43,
            status: .stopped,
            size: 4_000_000_000,
            labels: ["Archive"],
            statistics: .init(
                peersConnected: 0,
                downloadedEver: 1_720_000_000,
                uploadRatio: -1
            )
        ),
        RemoteTorrent(
            id: "queued-check",
            name: "Queued to verify local files",
            progress: 0.72,
            status: .queuedForCheck,
            size: 2_100_000_000,
            labels: [],
            verificationProgress: 0,
            statistics: .init(queuePosition: 1)
        ),
        RemoteTorrent(
            id: "checking",
            name: "Verifying local data",
            progress: 0.72,
            status: .checking,
            size: 2_100_000_000,
            labels: [],
            verificationProgress: 0.32,
            statistics: .init(queuePosition: 1)
        ),
        RemoteTorrent(
            id: "queued-download",
            name: "Queued Linux distribution download",
            progress: 0.12,
            status: .queuedForDownload,
            size: 5_300_000_000,
            labels: ["Linux"],
            statistics: .init(
                peersConnected: 12,
                downloadingFrom: 0,
                uploadingTo: 1,
                uploadRate: 18_000,
                eta: -2,
                queuePosition: 2
            ),
        ),
        remoteTorrent,
        RemoteTorrent(
            id: "queued-seed",
            name: "Completed release queued for seeding",
            progress: 1,
            status: .queuedForSeed,
            size: 3_750_000_000,
            labels: ["Media"],
            statistics: .init(
                peersConnected: 8,
                uploadingTo: 0,
                uploadRatio: 1.1,
                queuePosition: 3
            )
        ),
        RemoteTorrent(
            id: "seeding",
            name: "Completed release",
            progress: 1,
            status: .seeding,
            size: 3_750_000_000,
            labels: ["Media"],
            statistics: .init(
                peersConnected: 8,
                uploadingTo: 4,
                uploadRate: 850_000,
                uploadedEver: 9_000_000_000,
                downloadedEver: 3_750_000_000,
                uploadRatio: 2.4,
                etaIdle: 900,
                secondsSeeding: 3_600
            )
        ),
        RemoteTorrent(
            id: "unknown",
            name: "Future client status with an exceptionally long name for layout verification",
            progress: 0.67,
            status: .unknown("99"),
            size: 12_800_000_000,
            labels: [
                "Long organization label used to verify wrapping",
                "Unrecognized status"
            ],
            statistics: .init(
                peersConnected: 17,
                downloadRate: 512_000,
                uploadRate: 64_000,
                downloadedEver: 8_576_000_000,
                queuePosition: 4
            )
        )
    ]
    
    static var server: Server {
        Server(
            endpoint: URL(string: "http://endpoint/") ?? URL(fileURLWithPath: "/"),
            name: "Server #1",
            type: ServerType.transmission.rawValue
        )
    }
}

struct PreviewServerConnection: ServerConnection, GlobalSpeedLimitSupporting {

    func checkConnection() async throws {}

    #if os(iOS) || os(macOS)
    func addTorrent(_ request: TorrentAddRequest) async throws {
        throw ServerCommunicationError.notImplemented
    }
    #endif

    func getTorrent(id: String) async throws -> RemoteTorrent {
        throw ServerCommunicationError.notImplemented
    }

    func getTorrents() async throws -> [RemoteTorrent] {
        []
    }

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws {
    }

    func globalSpeedLimits() async throws -> GlobalSpeedLimits {
        .init(
            download: .init(bytesPerSecond: 1_000_000, isEnabled: true),
            upload: .init(bytesPerSecond: 500_000, isEnabled: false)
        )
    }

    func setGlobalSpeedLimits(_ limits: GlobalSpeedLimits) async throws {
    }
}
