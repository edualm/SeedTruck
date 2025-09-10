//
//  FloatingServerStatusView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct FloatingServerStatusView: View {
    
    let torrents: [RemoteTorrent]
    
    static private let rectanglePadding: CGFloat = 5
    
    var body: some View {
        HStack {
            Label("\(torrents.count)", systemImage: "square.stack.3d.down.right.fill")
                .labelStyle(.titleAndIcon)
                .padding(Self.rectanglePadding)
            Spacer()
            Group {
                Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.downloadSpeed), systemImage: "arrow.down.forward")
                    .labelStyle(.titleAndIcon)
                Label(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: torrents.uploadSpeed), systemImage: "arrow.up.forward")
                    .labelStyle(.titleAndIcon)
            }
            .padding(Self.rectanglePadding)
        }
        .padding(.horizontal)
    }
}

@available(iOS 26.0, *)
struct FloatingServerStatusView_Previews: PreviewProvider {
    
    static var previews: some View {
        TabView {
            Text("foo")
        }.tabViewBottomAccessory {
            FloatingServerStatusView(torrents:
                            [
                                PreviewMockData.remoteTorrent,
                                PreviewMockData.remoteTorrent,
                                PreviewMockData.remoteTorrent
                            ]
            )
        }
    }
}
