//
//  FloatingServerStatusView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

@available(iOS 26.0, *)
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
        .padding(.vertical, 5)
        .glassEffect()
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

@available(iOS 26.0, *)
struct FloatingServerStatusView_Previews: PreviewProvider {
    
    static var previews: some View {
        TabView {
            Text("foo")
                .safeAreaBar(edge: .bottom) {
                    FloatingServerStatusView(torrents:
                                    [
                                        PreviewMockData.remoteTorrent,
                                        PreviewMockData.remoteTorrent,
                                        PreviewMockData.remoteTorrent
                                    ]
                    )
                }
                .tabItem {
                    Label("Torrents", systemImage: "tray.and.arrow.down")
                }
        }
    }
}
