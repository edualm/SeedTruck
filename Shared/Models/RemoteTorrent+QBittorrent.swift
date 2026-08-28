//
//  RemoteTorrent+QBittorrent.swift
//  SeedTruck
//

import Foundation

extension RemoteTorrent {

    init?(from qbittorrentTorrent: QBittorrent.Torrent) {
        guard let id = qbittorrentTorrent.hash,
              !id.isEmpty,
              let name = qbittorrentTorrent.name,
              let progress = qbittorrentTorrent.progress,
              let rawState = qbittorrentTorrent.state,
              let size = qbittorrentTorrent.size else {
            return nil
        }

        let seeds = qbittorrentTorrent.numSeeds ?? 0
        let leeches = qbittorrentTorrent.numLeechs ?? 0
        let timeActive = qbittorrentTorrent.timeActive
        let seedingTime = qbittorrentTorrent.seedingTime
        let secondsDownloading: Int64?
        if let timeActive, let seedingTime {
            secondsDownloading = max(timeActive - seedingTime, 0)
        } else {
            secondsDownloading = timeActive
        }

        self.id = id
        self.name = name
        self.progress = progress
        self.verificationProgress = nil
        self.status = .init(qbittorrentState: rawState)
        self.size = size
        self.labels = Self.tags(from: qbittorrentTorrent.tags)
        self.statistics = Statistics(
            peersConnected: seeds + leeches,
            downloadingFrom: seeds,
            uploadingTo: leeches,
            downloadRate: qbittorrentTorrent.dlspeed ?? 0,
            uploadRate: qbittorrentTorrent.upspeed ?? 0,
            uploadedEver: qbittorrentTorrent.uploaded,
            downloadedEver: qbittorrentTorrent.downloaded,
            uploadRatio: Self.ratio(from: qbittorrentTorrent.ratio),
            eta: Self.eta(from: qbittorrentTorrent.eta),
            secondsDownloading: secondsDownloading,
            secondsSeeding: seedingTime,
            queuePosition: qbittorrentTorrent.priority.flatMap { $0 > 0 ? $0 - 1 : nil }
        )
    }

    private static func tags(from value: String?) -> [String] {
        guard let value else {
            return []
        }

        var seen = Set<String>()
        return value.split(separator: ",", omittingEmptySubsequences: false).compactMap { rawTag in
            let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tag.isEmpty, seen.insert(tag).inserted else {
                return nil
            }
            return tag
        }
    }

    private static func eta(from value: Int64?) -> Int64? {
        guard let value else {
            return nil
        }
        return value >= 8_640_000 ? -2 : value
    }

    private static func ratio(from value: Double?) -> Double? {
        guard let value else {
            return nil
        }
        return value >= 9_999 ? -2 : value
    }
}

extension RemoteTorrent.Status {

    init(qbittorrentState state: String) {
        switch state {
        case "stoppedDL", "stoppedUP", "pausedDL", "pausedUP":
            self = .stopped
        case "checkingResumeData":
            self = .queuedForCheck
        case "checkingDL", "checkingUP":
            self = .checking
        case "queuedDL":
            self = .queuedForDownload
        case "downloading", "metaDL", "forcedMetaDL", "stalledDL", "forcedDL", "allocating", "moving":
            self = .downloading
        case "queuedUP":
            self = .queuedForSeed
        case "uploading", "stalledUP", "forcedUP":
            self = .seeding
        default:
            self = .unknown(state)
        }
    }
}
