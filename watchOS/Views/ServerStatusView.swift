//
//  ServerStatusView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerStatusView: View {
    
    let summary: TorrentListSummary
    
    var body: some View {
        Group {
            if #available(watchOS 26.0, *) {
                statusContent
                    .glassEffect()
            } else {
                statusContent
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.18), radius: 5, y: 2)
            }
        }
        .scenePadding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Server transfer speed")
        .accessibilityValue(
            "Download speed \(downloadSpeed), upload speed \(uploadSpeed)"
        )
    }

    private var statusContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                downloadSpeedLabel
                uploadSpeedLabel
            }

            primarySpeedLabel
        }
        .font(.footnote.monospacedDigit())
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var primarySpeedLabel: some View {
        if summary.downloadSpeed >= summary.uploadSpeed {
            downloadSpeedLabel
        } else {
            uploadSpeedLabel
        }
    }

    private var downloadSpeed: String {
        ByteCountFormatter.humanReadableTransferRate(bytesPerSecond: summary.downloadSpeed)
    }

    private var uploadSpeed: String {
        ByteCountFormatter.humanReadableTransferRate(bytesPerSecond: summary.uploadSpeed)
    }

    private var downloadSpeedLabel: some View {
        Label(downloadSpeed, systemImage: "arrow.down.forward")
            .accessibilityLabel("Download speed")
            .accessibilityValue(downloadSpeed)
    }

    private var uploadSpeedLabel: some View {
        Label(uploadSpeed, systemImage: "arrow.up.forward")
            .accessibilityLabel("Upload speed")
            .accessibilityValue(uploadSpeed)
    }
}

struct ServerStatusView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerStatusView(summary: .init(
            visibleCount: 3,
            totalCount: 3,
            downloadSpeed: PreviewMockData.remoteTorrent.downloadRate,
            uploadSpeed: PreviewMockData.remoteTorrent.uploadRate
        ))
    }
}
