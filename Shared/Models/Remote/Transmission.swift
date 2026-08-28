//
//  Transmission.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

enum Transmission {

    struct RPCRequest<Parameters: Encodable>: Encodable {

        let jsonrpc = "2.0"
        let method: String
        let params: Parameters
        let id: String
    }

    struct RPCResponse<Value: Decodable>: Decodable {

        let jsonrpc: String
        let result: Value?
        let error: RPCError?
        let id: String?
    }

    struct RPCError: Decodable {

        let code: Int
        let message: String
        let data: RPCErrorData?
    }

    struct RPCErrorData: Decodable {

        let errorString: String?
    }

    struct EmptyResult: Decodable {}

    struct TorrentGetParameters: Encodable {

        let fields: [String]
        let ids: [Int]?
    }

    struct TorrentGetResult: Decodable {

        let torrents: [Torrent]
    }

    struct TorrentAddParameters: Encodable {

        let filename: String?
        let metainfo: String?
        let labels: [String]?
    }

    struct TorrentAddResult: Decodable {

        let torrentAdded: TorrentAdded?
        let torrentDuplicate: TorrentAdded?
    }

    struct TorrentIDsParameters: Encodable {

        let ids: [Int]
    }

    struct TorrentRemoveParameters: Encodable {

        let ids: [Int]
        let deleteLocalData: Bool
    }

    struct SessionGetParameters: Encodable {

        let fields: [String]
    }

    struct SessionSpeedLimits: Decodable {

        let speedLimitDown: Double?
        let speedLimitUp: Double?
        let speedLimitDownEnabled: Bool?
        let speedLimitUpEnabled: Bool?
    }

    struct SessionSetParameters: Encodable {

        let speedLimitDown: Int
        let speedLimitDownEnabled: Bool
        let speedLimitUp: Int
        let speedLimitUpEnabled: Bool
    }
    
    struct TorrentAdded: Codable {
        
        let hashString: String
        let id: Int
        let name: String
    }
    
    struct Torrent: Codable {
        
        struct File: Codable {
            
            let bytesCompleted: Int
            let length: Int
            let name: String
        }
        
        struct FileStats: Codable {
            
            let bytesCompleted: Int
            let wanted: Bool
            let priority: Int
        }
        
        struct Peer: Codable {
            
            let address: String
            let clientName: String
            let clientIsChoked: Bool
            let clientIsInterested: Bool
            let flagStr: String
            let isDownloadingFrom: Bool
            let isEncrypted: Bool
            let isIncoming: Bool
            let isUploadingTo: Bool
            let isUtp: Bool
            let peerIsChoked: Bool
            let peerIsInterested: Bool
            let port: Int
            let progress: Double
            let rateToClient: Int
            let rateToPeer: Int
        }
        
        struct PeersFrom: Codable {
            
            let fromCache: Int
            let fromDht: Int
            let fromIncoming: Int
            let fromLpd: Int
            let fromLtep: Int
            let fromPex: Int
            let fromTracker: Int
        }
        
        struct Tracker: Codable {
            
            let announce: String
            let id: Int
            let scrape: String
            let tier: Int
        }
        
        struct TrackerStats: Codable {
            
            let announce: String
            let announceState: Int
            let downloadCount: Int
            let hasAnnounced: Bool
            let hasScraped: Bool
            let host: String
            let id: Int
            let isBackup: Bool
            let lastAnnouncePeerCount: Int
            let lastAnnounceResult: String
            let lastAnnounceStartTime: Int
            let lastAnnounceSucceeded: Bool
            let lastAnnounceTime: Int
            let lastAnnounceTimedOut: Bool
            let lastScrapeResult: String
            let lastScrapeStartTime: Int
            let lastScrapeSucceeded: Bool
            let lastScrapeTime: Int
            let lastScrapeTimedOut: Bool
            let leecherCount: Int
            let nextAnnounceTime: Int
            let nextScrapeTime: Int
            let scrape: String
            let scrapeState: Int
            let seederCount: Int
            let tier: Int
        }
        
        let activityDate: Int?
        let addedDate: Int?
        let bandwidthPriority: Int?
        let comment: String?
        let corruptEver: Int?
        let creator: String?
        let dateCreated: Int?
        let desiredAvailable: Int?
        let doneDate: Int?
        let downloadDir: String?
        let downloadedEver: Int64?
        let downloadLimit: Int?
        let downloadLimited: Bool?
        let editDate: Int?
        let error: Int?
        let errorString: String?
        let eta: Int64?
        let etaIdle: Int64?
        let files: [File]?
        let fileStats: [FileStats]?
        let hashString: String?
        let haveUnchecked: Int?
        let haveValid: Int?
        let honorsSessionLimits: Bool?
        let id: Int?
        let isFinished: Bool?
        let isPrivate: Bool?
        let isStalled: Bool?
        let labels: [String]?
        let leftUntilDone: Int?
        let magnetLink: String?
        let manualAnnounceTime: Int?
        let maxConnectedPeers: Int?
        let metadataPercentComplete: Double?
        let name: String?
        let peerLimit: Int? //  peer-limit
        let peers: [Peer]?
        let peersConnected: Int?
        let peersFrom: PeersFrom?
        let peersGettingFromUs: Int?
        let peersSendingToUs: Int?
        let percentDone: Double?
        let pieces: String?
        let pieceCount: Int?
        let pieceSize: Int?
        let priorities: [Int]?
        let queuePosition: Int?
        let rateDownload: Int?
        let rateUpload: Int?
        let recheckProgress: Double?
        let secondsDownloading: Int?
        let secondsSeeding: Int64?
        let seedIdleLimit: Int?
        let seedIdleMode: Int?
        let seedRatioLimit: Double?
        let seedRatioMode: Int?
        let sizeWhenDone: Int64?
        let startDate: Int?
        let status: Int?
        let trackers: [Tracker]?
        let trackerStats: [TrackerStats]?
        let totalSize: Int?
        let torrentFile: String?
        let uploadedEver: Int64?
        let uploadLimit: Int?
        let uploadLimited: Bool?
        let uploadRatio: Double?
        let wanted: [Bool]?
        let webseeds: [String]?
        let webseedsSendingToUs: Int?
    }
}
