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
                    Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: downloadRate), systemImage: "chevron.down")
                        .font(.footnote)
                    Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate), systemImage: "chevron.up")
                        .font(.footnote)
                }
            case let .seeding(_, uploadRate):
                HStack {
                    Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate), systemImage: "chevron.up")
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
            ProgressBarView(cornerRadius: 10.0, progress: CGFloat(torrent.progress))
                .frame(width: nil, height: 20, alignment: .center)
            SpeedView(torrent: torrent)
        }
    }
}

struct TorrentItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TorrentItemView(torrent: PreviewMockData.torrent)
        }.previewLayout(.fixed(width: 400, height: 100))
    }
}
