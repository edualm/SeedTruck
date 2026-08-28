//
//  RemoteTorrent.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

typealias Filter = RemoteTorrent.Status.Simple

struct RemoteTorrent: Identifiable, Hashable, Sendable {

    struct Statistics: Hashable, Sendable {

        static let empty = Statistics()

        let peersConnected: Int
        let downloadingFrom: Int
        let uploadingTo: Int
        let downloadRate: Int
        let uploadRate: Int
        let uploadedEver: Int64?
        let downloadedEver: Int64?
        let uploadRatio: Double?
        let eta: Int64?
        let etaIdle: Int64?
        let secondsDownloading: Int64?
        let secondsSeeding: Int64?
        let queuePosition: Int?

        init(
            peersConnected: Int = 0,
            downloadingFrom: Int = 0,
            uploadingTo: Int = 0,
            downloadRate: Int = 0,
            uploadRate: Int = 0,
            uploadedEver: Int64? = nil,
            downloadedEver: Int64? = nil,
            uploadRatio: Double? = nil,
            eta: Int64? = nil,
            etaIdle: Int64? = nil,
            secondsDownloading: Int64? = nil,
            secondsSeeding: Int64? = nil,
            queuePosition: Int? = nil
        ) {
            self.peersConnected = peersConnected
            self.downloadingFrom = downloadingFrom
            self.uploadingTo = uploadingTo
            self.downloadRate = downloadRate
            self.uploadRate = uploadRate
            self.uploadedEver = uploadedEver
            self.downloadedEver = downloadedEver
            self.uploadRatio = uploadRatio
            self.eta = eta
            self.etaIdle = etaIdle
            self.secondsDownloading = secondsDownloading
            self.secondsSeeding = secondsSeeding
            self.queuePosition = queuePosition
        }
    }
    
    enum Status: Hashable, Sendable {
        
        enum Simple: CaseIterable, Hashable, Identifiable, Sendable {
            
            case stopped
            case downloading
            case seeding
            case other

            var id: Self { self }
        }
        
        case stopped
        case queuedForCheck
        case checking
        case queuedForDownload
        case downloading
        case queuedForSeed
        case seeding
        case unknown(String)
        
        var simple: Simple {
            switch self {
            case .stopped:
                return .stopped
                
            case .queuedForDownload, .downloading:
                return .downloading

            case .queuedForSeed, .seeding:
                return .seeding

            case .queuedForCheck, .checking, .unknown:
                return .other
            }
        }
    }
    
    let id: String
    let name: String
    let progress: Double
    let verificationProgress: Double?
    let status: Status
    let size: Int64
    let labels: [String]
    let statistics: Statistics

    init(
        id: String,
        name: String,
        progress: Double,
        status: Status,
        size: Int64,
        labels: [String],
        verificationProgress: Double? = nil,
        statistics: Statistics = .empty
    ) {
        self.id = id
        self.name = name
        self.progress = progress
        self.verificationProgress = verificationProgress
        self.status = status
        self.size = size
        self.labels = labels
        self.statistics = statistics
    }
}
