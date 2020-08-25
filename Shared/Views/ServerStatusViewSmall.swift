//
//  ServerStatusViewSmall.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerStatusViewSmall: View {
    
    let torrents: [RemoteTorrent]
    
    var body: some View {
        HStack {
            Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.downloadSpeed), systemImage: "chevron.down")
            Spacer()
            Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.downloadSpeed), systemImage: "chevron.up")
        }
    }
}

struct ServerStatusViewSmall_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerStatusViewSmall(torrents:
                                [
                                    PreviewMockData.remoteTorrent,
                                    PreviewMockData.remoteTorrent,
                                    PreviewMockData.remoteTorrent
                                ]
        )
    }
}