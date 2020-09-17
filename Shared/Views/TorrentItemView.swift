//
//  TorrentItemView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentItemView: View {
    
    struct SpeedView: View {
        
        let torrent: RemoteTorrent
        
        var body: some View {
            switch torrent.status {
            case .idle:
                Text("Idle")
                    .fontWeight(.light)
                
            case let .downloading(_, _, _, downloadRate, uploadRate):
                HStack {
                    Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: downloadRate), systemImage: "arrow.down.forward")
                        .font(.footnote)
                    Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate), systemImage: "arrow.up.forward")
                        .font(.footnote)
                }
                
            case let .seeding(_, uploadRate, _, _):
                VStack {
                    Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate), systemImage: "arrow.up.forward")
                        .font(.footnote)
                }
            }
        }
    }
    
    var torrent: RemoteTorrent
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(torrent.name)
                .bold()
                .lineLimit(1)
            ProgressBarView(cornerRadius: 10.0, progress: CGFloat(torrent.progress))
                .frame(width: nil, height: 20, alignment: .center)
            SpeedView(torrent: torrent)
        }
    }
}

struct TorrentItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentItemView(torrent: PreviewMockData.remoteTorrent)
        }.previewLayout(.fixed(width: 400, height: 100))
    }
}
