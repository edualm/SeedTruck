//
//  RemoteTorrent+Transmission.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

extension RemoteTorrent {
    
    init?(from transmissionTorrent: Transmission.Torrent) {
        guard let id = transmissionTorrent.id,
              let name = transmissionTorrent.name,
              let progress = transmissionTorrent.percentDone,
              let status = transmissionTorrent.status,
              let size = transmissionTorrent.sizeWhenDone else {
            
            return nil
        }
        
        self.id = String(id)
        self.name = name
        self.progress = progress
        self.verificationProgress = transmissionTorrent.recheckProgress
        self.size = size
        self.labels = transmissionTorrent.labels ?? []
        self.status = Status(transmissionCode: status)
        self.statistics = Statistics(
            peersConnected: transmissionTorrent.peersConnected ?? 0,
            downloadingFrom: transmissionTorrent.peersSendingToUs ?? 0,
            uploadingTo: transmissionTorrent.peersGettingFromUs ?? 0,
            downloadRate: transmissionTorrent.rateDownload ?? 0,
            uploadRate: transmissionTorrent.rateUpload ?? 0,
            uploadedEver: transmissionTorrent.uploadedEver,
            downloadedEver: transmissionTorrent.downloadedEver,
            uploadRatio: transmissionTorrent.uploadRatio,
            eta: transmissionTorrent.eta,
            etaIdle: transmissionTorrent.etaIdle,
            secondsDownloading: transmissionTorrent.secondsDownloading.map(Int64.init),
            secondsSeeding: transmissionTorrent.secondsSeeding,
            queuePosition: transmissionTorrent.queuePosition
        )
    }
}

extension RemoteTorrent.Status {

    init(transmissionCode: Int) {
        switch transmissionCode {
        case 0:
            self = .stopped
        case 1:
            self = .queuedForCheck
        case 2:
            self = .checking
        case 3:
            self = .queuedForDownload
        case 4:
            self = .downloading
        case 5:
            self = .queuedForSeed
        case 6:
            self = .seeding
        default:
            self = .unknown(String(transmissionCode))
        }
    }
}
