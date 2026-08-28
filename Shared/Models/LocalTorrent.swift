//
//  LocalTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

struct TorrentImportLimits: Equatable, Sendable {

    static let appDefault = TorrentImportLimits(
        maximumEncodedBytes: 16 * 1_024 * 1_024,
        maximumDepth: 64,
        maximumNodes: 100_000,
        maximumFiles: 25_000,
        maximumPathComponents: 128,
        maximumTextBytes: 4_096
    )

    let maximumEncodedBytes: Int
    let maximumDepth: Int
    let maximumNodes: Int
    let maximumFiles: Int
    let maximumPathComponents: Int
    let maximumTextBytes: Int
}

enum TorrentImportError: Error, Equatable, LocalizedError, Sendable {

    case unsupportedType
    case unreadableFile
    case fileTooLarge(maximumBytes: Int)
    case malformedMetadata
    case metadataLimitExceeded

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "Choose a valid .torrent file or magnet link."
        case .unreadableFile:
            return "The torrent file could not be read."
        case .fileTooLarge(let maximumBytes):
            let maximumSize = ByteCountFormatter.humanReadableFileSize(bytes: Int64(maximumBytes))
            return "The torrent file exceeds the \(maximumSize) import limit."
        case .malformedMetadata:
            return "The torrent file contains malformed or unsupported metadata."
        case .metadataLimitExceeded:
            return "The torrent metadata is too complex to import safely."
        }
    }
}

enum LocalTorrent: Sendable {

    struct File: Equatable, Sendable {

        let path: String
        let size: Int64
    }

    struct Metadata: Equatable, Sendable {

        let name: String
        let isPrivate: Bool?
        let files: [File]
        let totalSize: Int64
    }
    
    case magnet(String, labels: [String] = [])
    case torrent(data: Data, metadata: Metadata, labels: [String] = [])
    
    var labels: [String] {
        switch self {
        case .magnet(_, let labels):
            return labels
        case .torrent(_, _, let labels):
            return labels
        }
    }
    
    func withLabels(_ labels: [String]) -> LocalTorrent {
        switch self {
        case .magnet(let magnet, _):
            return .magnet(magnet, labels: labels)
        case .torrent(let data, let metadata, _):
            return .torrent(data: data, metadata: metadata, labels: labels)
        }
    }
}
