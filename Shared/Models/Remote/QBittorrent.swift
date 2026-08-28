//
//  QBittorrent.swift
//  SeedTruck
//

import Foundation

enum QBittorrent {

    struct Torrent: Decodable, Sendable {

        let hash: String?
        let name: String?
        let progress: Double?
        let state: String?
        let size: Int64?
        let tags: String?
        let dlspeed: Int?
        let upspeed: Int?
        let downloaded: Int64?
        let uploaded: Int64?
        let ratio: Double?
        let eta: Int64?
        let numSeeds: Int?
        let numLeechs: Int?
        let timeActive: Int64?
        let seedingTime: Int64?
        let priority: Int?
    }
}
