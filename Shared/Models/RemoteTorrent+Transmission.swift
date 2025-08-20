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
        self.size = size
        self.labels = transmissionTorrent.labels ?? []
        
        switch status {
        case 0:
            self.status = .stopped
            
        case 1:
            self.status = .other("Preparing/waiting to check")
        
        case 2:
            self.status = .other("Checking")
            
        case 3:
            self.status = .other("Waiting for download")
            
        case 4:
            guard let peers = transmissionTorrent.peersConnected,
                  let uploadRate = transmissionTorrent.rateUpload,
                  let peersSending = transmissionTorrent.peersSendingToUs,
                  let peersReceiving = transmissionTorrent.peersGettingFromUs,
                  let downloadRate = transmissionTorrent.rateDownload,
                  let eta = transmissionTorrent.eta else {
                
                return nil
            }
            
            self.status = .downloading(peers: peers, peersSending: peersSending, peersReceiving: peersReceiving, downloadRate: downloadRate, uploadRate: uploadRate, eta: eta)
            
        case 5:
            self.status = .other("Preparing/waiting to seed")
            
        case 6:
            guard let peers = transmissionTorrent.peersConnected,
                  let uploadRate = transmissionTorrent.rateUpload,
                  let ratio = transmissionTorrent.uploadRatio else {
                
                return nil
            }
            
            self.status = .seeding(peers: peers, uploadRate: uploadRate, ratio: ratio, totalUploaded: transmissionTorrent.uploadedEver, secondsSeeding: transmissionTorrent.secondsSeeding, etaIdle: transmissionTorrent.etaIdle)
            
        default:
            return nil
        }
    }
}
