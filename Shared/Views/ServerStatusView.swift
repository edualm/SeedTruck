//
//  ServerStatusView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerStatusView: View {
    
    let torrents: [RemoteTorrent]
    
    #if os(tvOS)
    static private let rectanglePadding: CGFloat = 10
    #else
    static private let rectanglePadding: CGFloat = 5
    #endif
    
    var body: some View {
        HStack {
            Label("\(torrents.count)", systemImage: "square.stack.3d.down.right.fill")
                .padding(Self.rectanglePadding)
                .background(Color.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 5.0))
            Spacer()
            Group {
                Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.downloadSpeed), systemImage: "arrow.down.forward")
                Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.uploadSpeed), systemImage: "arrow.up.forward")
            }
            .padding(Self.rectanglePadding)
            .background(Color.secondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 5.0))
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .padding(.bottom, 10)
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
