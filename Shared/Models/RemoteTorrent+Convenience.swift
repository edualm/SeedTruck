//
//  RemoteTorrent+Convenience.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

enum TorrentSort: String, CaseIterable, Identifiable, Sendable {

    case name
    case activity
    case progress
    case speed

    var id: Self { self }

    var label: String {
        switch self {
        case .name:
            return "Name"
        case .activity:
            return "Activity"
        case .progress:
            return "Progress"
        case .speed:
            return "Speed"
        }
    }

    var systemImage: String {
        switch self {
        case .name:
            return "textformat"
        case .activity:
            return "waveform.path"
        case .progress:
            return "chart.bar.fill"
        case .speed:
            return "speedometer"
        }
    }
}

enum TorrentSortDirection: String, CaseIterable, Identifiable, Sendable {

    case ascending
    case descending

    var id: Self { self }

    var label: String {
        switch self {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }

    var systemImage: String {
        switch self {
        case .ascending:
            return "arrow.up"
        case .descending:
            return "arrow.down"
        }
    }
}

struct TorrentListSummary: Equatable, Sendable {

    let visibleCount: Int
    let totalCount: Int
    let downloadSpeed: Int
    let uploadSpeed: Int

    static let empty = TorrentListSummary(
        visibleCount: 0,
        totalCount: 0,
        downloadSpeed: 0,
        uploadSpeed: 0
    )

    var countLabel: String {
        visibleCount == totalCount ? "\(totalCount)" : "\(visibleCount) of \(totalCount)"
    }
}

struct TorrentListProjection: Equatable, Sendable {

    let torrents: [RemoteTorrent]
    let summary: TorrentListSummary
    let isFiltered: Bool

    init(
        torrents: [RemoteTorrent],
        filter: Filter?,
        query: String,
        sort: TorrentSort,
        sortDirection: TorrentSortDirection
    ) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleTorrents = torrents.filter { torrent in
            let matchesQuery = trimmedQuery.isEmpty || torrent.name.localizedCaseInsensitiveContains(trimmedQuery)
            let matchesFilter = filter == nil || torrent.status.simple == filter
            return matchesQuery && matchesFilter
        }

        self.torrents = visibleTorrents.sorted(using: sort, direction: sortDirection)
        self.summary = TorrentListSummary(
            visibleCount: visibleTorrents.count,
            totalCount: torrents.count,
            downloadSpeed: torrents.downloadSpeed,
            uploadSpeed: torrents.uploadSpeed
        )
        self.isFiltered = filter != nil || !trimmedQuery.isEmpty
    }
}

enum TorrentListPresentationState: Equatable, Sendable {

    case noServer
    case initialLoading
    case initialError(String)
    case empty(isRefreshing: Bool, refreshError: String?)
    case noResults(TorrentListProjection, isRefreshing: Bool, refreshError: String?)
    case content(TorrentListProjection, isRefreshing: Bool, refreshError: String?)

    init(
        hasServer: Bool,
        hasLoaded: Bool,
        isRefreshing: Bool,
        refreshError: String?,
        projection: TorrentListProjection
    ) {
        guard hasServer else {
            self = .noServer
            return
        }

        guard hasLoaded else {
            if isRefreshing {
                self = .initialLoading
            } else if let refreshError {
                self = .initialError(refreshError)
            } else {
                self = .initialLoading
            }
            return
        }

        if projection.summary.totalCount == 0 {
            self = .empty(isRefreshing: isRefreshing, refreshError: refreshError)
        } else if projection.torrents.isEmpty {
            self = .noResults(projection, isRefreshing: isRefreshing, refreshError: refreshError)
        } else {
            self = .content(projection, isRefreshing: isRefreshing, refreshError: refreshError)
        }
    }
}

extension RemoteTorrent.Status {

    var displayableStatus: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .queuedForCheck:
            return "Queued for verification"
        case .checking:
            return "Verifying local data"
        case .queuedForDownload:
            return "Queued for download"
        case .downloading:
            return "Downloading"
        case .queuedForSeed:
            return "Queued for seeding"
        case .seeding:
            return "Seeding"
        case .unknown(let state):
            return "Unknown status (\(state))"
        }
    }

    var systemImage: String {
        switch self {
        case .stopped:
            return "stop.circle.fill"
        case .queuedForCheck:
            return "clock.arrow.circlepath"
        case .checking:
            return "checkmark.circle.fill"
        case .queuedForDownload:
            return "arrow.down.circle.dotted"
        case .downloading:
            return "arrow.down.circle.fill"
        case .queuedForSeed:
            return "arrow.up.circle.dotted"
        case .seeding:
            return "arrow.up.circle.fill"
        case .unknown:
            return "clock.badge.questionmark.fill"
        }
    }
}

extension RemoteTorrent.Status.Simple {

    var label: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .downloading:
            return "Downloading"
        case .seeding:
            return "Seeding"
        case .other:
            return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .stopped:
            return "stop.circle"
        case .downloading:
            return "arrow.down.forward.circle"
        case .seeding:
            return "arrow.up.forward.circle"
        case .other:
            return "questionmark.circle"
        }
    }
}

struct TorrentActionCapabilities: Equatable, Sendable {

    let canStart: Bool
    let canStop: Bool
    let canRemove: Bool
}

struct TorrentDetailProgress: Equatable, Sendable {

    enum Kind: Equatable, Sendable {
        case download
        case verification
    }

    let kind: Kind
    let fraction: Double

    var label: String {
        switch kind {
        case .download:
            return "Download progress"
        case .verification:
            return "Verification progress"
        }
    }

    var percentageText: String {
        String(format: "%.0f%%", fraction * 100)
    }
}

struct TorrentDetailMetric: Identifiable, Equatable, Sendable {

    enum Identifier: String, Hashable, Sendable {
        case connectedPeers
        case downloaded
        case downloadingFrom
        case downloadSpeed
        case downloadTime
        case labels
        case queuePosition
        case ratio
        case seedingTime
        case size
        case uploaded
        case uploadingTo
        case uploadSpeed
    }

    let id: Identifier
    let label: String
    let value: String
    let systemImage: String
}

struct TorrentDetailProjection: Equatable, Sendable {

    let statusText: String
    let statusSystemImage: String
    let progress: TorrentDetailProgress
    let etaLabel: String?
    let etaText: String
    let primaryAction: RemoteTorrent.Action?
    let metrics: [TorrentDetailMetric]

    init(torrent: RemoteTorrent) {
        statusText = torrent.status.displayableStatus
        statusSystemImage = torrent.status.systemImage
        progress = torrent.detailProgress
        primaryAction = torrent.primaryAction

        switch torrent.status {
        case .queuedForDownload, .downloading:
            etaLabel = "Time remaining"
            etaText = Self.etaText(torrent.statistics.eta)
        case .queuedForSeed, .seeding:
            etaText = Self.etaText(torrent.statistics.etaIdle)
            etaLabel = etaText == "Not available" ? nil : "Idle limit"
        default:
            etaLabel = "ETA"
            etaText = "Not available"
        }

        var metrics = [
            TorrentDetailMetric(
                id: .size,
                label: "Size",
                value: ByteCountFormatter.humanReadableFileSize(bytes: torrent.size),
                systemImage: "externaldrive"
            ),
            TorrentDetailMetric(
                id: .downloadSpeed,
                label: "Download speed",
                value: ByteCountFormatter.humanReadableTransferRate(
                    bytesPerSecond: torrent.statistics.downloadRate
                ),
                systemImage: "arrow.down.forward"
            ),
            TorrentDetailMetric(
                id: .uploadSpeed,
                label: "Upload speed",
                value: ByteCountFormatter.humanReadableTransferRate(
                    bytesPerSecond: torrent.statistics.uploadRate
                ),
                systemImage: "arrow.up.forward"
            ),
            TorrentDetailMetric(
                id: .connectedPeers,
                label: "Connected peers",
                value: "\(torrent.statistics.peersConnected)",
                systemImage: "person.3"
            ),
            TorrentDetailMetric(
                id: .downloadingFrom,
                label: "Downloading from",
                value: "\(torrent.statistics.downloadingFrom)",
                systemImage: "person.and.arrow.left.and.arrow.right"
            ),
            TorrentDetailMetric(
                id: .uploadingTo,
                label: "Uploading to",
                value: "\(torrent.statistics.uploadingTo)",
                systemImage: "person.and.arrow.left.and.arrow.right"
            )
        ]

        if let ratio = torrent.statistics.uploadRatio {
            metrics.append(
                .init(
                    id: .ratio,
                    label: "Ratio",
                    value: Self.ratioText(ratio),
                    systemImage: "arrow.up.arrow.down"
                )
            )
        }
        if let uploaded = torrent.statistics.uploadedEver {
            metrics.append(
                .init(
                    id: .uploaded,
                    label: "Uploaded",
                    value: ByteCountFormatter.humanReadableFileSize(bytes: uploaded),
                    systemImage: "arrow.up.to.line"
                )
            )
        }
        if let downloaded = torrent.statistics.downloadedEver {
            metrics.append(
                .init(
                    id: .downloaded,
                    label: "Downloaded",
                    value: ByteCountFormatter.humanReadableFileSize(bytes: downloaded),
                    systemImage: "arrow.down.to.line"
                )
            )
        }
        if let queuePosition = torrent.statistics.queuePosition,
           torrent.status.isQueued {
            metrics.append(
                .init(
                    id: .queuePosition,
                    label: "Queue position",
                    value: "\(queuePosition + 1)",
                    systemImage: "list.number"
                )
            )
        }
        if let secondsDownloading = torrent.statistics.secondsDownloading,
           let duration = Self.durationText(secondsDownloading) {
            metrics.append(
                .init(
                    id: .downloadTime,
                    label: "Downloading time",
                    value: duration,
                    systemImage: "clock.arrow.circlepath"
                )
            )
        }
        if let secondsSeeding = torrent.statistics.secondsSeeding,
           let duration = Self.durationText(secondsSeeding) {
            metrics.append(
                .init(
                    id: .seedingTime,
                    label: "Seeding time",
                    value: duration,
                    systemImage: "deskclock"
                )
            )
        }
        if !torrent.labels.isEmpty {
            metrics.append(
                .init(
                    id: .labels,
                    label: "Labels",
                    value: torrent.labels.joined(separator: ", "),
                    systemImage: "tag"
                )
            )
        }

        self.metrics = metrics
    }

    private static func etaText(_ seconds: Int64?) -> String {
        guard let seconds else {
            return "Not available"
        }
        switch seconds {
        case -2:
            return "Unknown"
        case -1:
            return "Not available"
        default:
            return durationText(seconds) ?? "Not available"
        }
    }

    private static func ratioText(_ ratio: Double) -> String {
        switch ratio {
        case -2:
            return "Infinite"
        case -1:
            return "Not available"
        default:
            return String(format: "%.2f", ratio)
        }
    }

    private static func durationText(_ seconds: Int64) -> String? {
        guard seconds >= 0 else {
            return nil
        }
        guard seconds > 0 else {
            return "0 sec"
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(seconds))
    }
}

struct TorrentRemovalConfirmation: Identifiable, Equatable, Sendable {

    let id: RemoteTorrent.RemovalPolicy
    let title: String
    let message: String
    let confirmButtonTitle: String

    init(torrent: RemoteTorrent, policy: RemoteTorrent.RemovalPolicy) {
        id = policy
        let size = ByteCountFormatter.humanReadableFileSize(bytes: torrent.size)

        switch policy {
        case .keepLocalData:
            title = "Remove Torrent and Keep Files?"
            message = "Remove \"\(torrent.name)\" (\(size)) from the server. Its downloaded files will remain on disk."
            confirmButtonTitle = "Remove and Keep Files"
        case .deleteLocalData:
            title = "Remove Torrent and Delete Files?"
            message = "Remove \"\(torrent.name)\" (\(size)) from the server and permanently delete its downloaded files."
            confirmButtonTitle = "Remove and Delete Files"
        }
    }
}

extension RemoteTorrent {

    var downloadRate: Int {
        statistics.downloadRate
    }

    var uploadRate: Int {
        statistics.uploadRate
    }

    var transferSpeed: Int {
        downloadRate + uploadRate
    }

    var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    var detailProgress: TorrentDetailProgress {
        switch status {
        case .queuedForCheck, .checking:
            return .init(
                kind: .verification,
                fraction: min(max(verificationProgress ?? progress, 0), 1)
            )
        default:
            return .init(kind: .download, fraction: normalizedProgress)
        }
    }

    var actionCapabilities: TorrentActionCapabilities {
        switch status {
        case .stopped:
            return .init(canStart: true, canStop: false, canRemove: true)
        case .queuedForCheck, .checking, .queuedForDownload, .downloading, .queuedForSeed, .seeding:
            return .init(canStart: false, canStop: true, canRemove: true)
        case .unknown:
            return .init(canStart: false, canStop: false, canRemove: true)
        }
    }

    var primaryAction: Action? {
        if actionCapabilities.canStart {
            return .start
        }
        if actionCapabilities.canStop {
            return .stop
        }
        return nil
    }

    fileprivate var activityRank: Int {
        switch status {
        case .queuedForDownload, .downloading:
            return 0
        case .queuedForSeed, .seeding:
            return 1
        case .queuedForCheck, .checking:
            return 2
        case .stopped:
            return 3
        case .unknown:
            return 4
        }
    }
}

extension RemoteTorrent.Status {

    fileprivate var isQueued: Bool {
        switch self {
        case .queuedForCheck, .queuedForDownload, .queuedForSeed:
            return true
        default:
            return false
        }
    }
}

extension RemoteTorrent.Action {

    var displayName: String {
        switch self {
        case .start:
            return "Start"
        case .stop:
            return "Pause"
        case .remove(.keepLocalData):
            return "Remove and Keep Files"
        case .remove(.deleteLocalData):
            return "Remove and Delete Files"
        }
    }

    var systemImage: String {
        switch self {
        case .start:
            return "play.fill"
        case .stop:
            return "pause.fill"
        case .remove(.keepLocalData):
            return "xmark.circle"
        case .remove(.deleteLocalData):
            return "trash"
        }
    }
}

private extension Array where Element == RemoteTorrent {

    func sorted(using sort: TorrentSort, direction: TorrentSortDirection) -> [RemoteTorrent] {
        sorted { lhs, rhs in
            switch sort {
            case .name:
                let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if comparison != .orderedSame {
                    return direction == .ascending
                        ? comparison == .orderedAscending
                        : comparison == .orderedDescending
                }
            case .activity:
                if lhs.activityRank != rhs.activityRank {
                    return direction == .ascending
                        ? lhs.activityRank < rhs.activityRank
                        : lhs.activityRank > rhs.activityRank
                }
            case .progress:
                if lhs.normalizedProgress != rhs.normalizedProgress {
                    return direction == .ascending
                        ? lhs.normalizedProgress < rhs.normalizedProgress
                        : lhs.normalizedProgress > rhs.normalizedProgress
                }
            case .speed:
                if lhs.transferSpeed != rhs.transferSpeed {
                    return direction == .ascending
                        ? lhs.transferSpeed < rhs.transferSpeed
                        : lhs.transferSpeed > rhs.transferSpeed
                }
            }

            return lhs.isOrderedBefore(rhs)
        }
    }
}

private extension RemoteTorrent {

    func isOrderedBefore(_ other: RemoteTorrent) -> Bool {
        let comparison = name.localizedCaseInsensitiveCompare(other.name)
        return comparison == .orderedSame ? id < other.id : comparison == .orderedAscending
    }
}

extension Array where Iterator.Element == RemoteTorrent {
    
    var downloadSpeed: Int {
        reduce(0) { $0 + $1.downloadRate }
    }
    
    var uploadSpeed: Int {
        reduce(0) { $0 + $1.uploadRate }
    }
}
