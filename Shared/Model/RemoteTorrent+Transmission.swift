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
        
        switch status {
        case 0:
            self.status = .idle
            
        case 4:
            guard let peers = transmissionTorrent.peersConnected,
                  let uploadRate = transmissionTorrent.rateUpload,
                  let peersSending = transmissionTorrent.peersSendingToUs,
                  let peersReceiving = transmissionTorrent.peersGettingFromUs,
                  let downloadRate = transmissionTorrent.rateDownload else {
                
                return nil
            }
            
            self.status = .downloading(peers: peers, peersSending: peersSending, peersReceiving: peersReceiving, downloadRate: downloadRate, uploadRate: uploadRate)
            
        case 6:
            guard let peers = transmissionTorrent.peersConnected, let uploadRate = transmissionTorrent.rateUpload else {
                return nil
            }
            
            self.status = .seeding(peers: peers, uploadRate: uploadRate)
        default:
            return nil
        }
        
        self.size = size
    }
}
