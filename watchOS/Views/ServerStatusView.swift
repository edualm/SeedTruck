//
//  ServerStatusView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerStatusView: View {
    
    let torrents: [RemoteTorrent]
    
    var body: some View {
        HStack {
            Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.downloadSpeed), systemImage: "arrow.down.forward")
            Spacer()
            Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.uploadSpeed), systemImage: "arrow.up.forward")
        }
    }
}

struct ServerStatusView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerStatusView(torrents:
                            [
                                PreviewMockData.remoteTorrent,
                                PreviewMockData.remoteTorrent,
                                PreviewMockData.remoteTorrent
                            ]
        )
    }
}
