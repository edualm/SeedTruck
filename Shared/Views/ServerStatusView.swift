//
//  ServerStatusView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerStatusView: View {
    
    let summary: TorrentListSummary
    
    #if os(tvOS)
    static private let rectanglePadding: CGFloat = 10
    #else
    static private let rectanglePadding: CGFloat = 5
    #endif
    
    var body: some View {
        #if os(macOS)
        Group {
            if #available(macOS 26.0, *) {
                floatingContent
                    .glassEffect()
            } else {
                floatingContent
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 3)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.visibleCount) of \(summary.totalCount) torrents shown")
        .accessibilityValue(
            "Download speed \(downloadSpeed), upload speed \(uploadSpeed)"
        )
        #else
        statusContent
            .padding(.horizontal)
            .padding(.vertical, 5)
            .padding(.bottom, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(summary.visibleCount) of \(summary.totalCount) torrents shown")
            .accessibilityValue(
                "Download speed \(downloadSpeed), upload speed \(uploadSpeed)"
            )
        #endif
    }

    private var statusContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                countLabel
                Spacer(minLength: 8)
                speedLabels
            }

            speedLabels
            primarySpeedLabel
        }
        .lineLimit(1)
    }

    #if os(macOS)
    private var floatingContent: some View {
        statusContent
            .padding(.horizontal)
            .padding(.vertical, 5)
    }
    #endif

    private var countLabel: some View {
        Label(summary.countLabel, systemImage: "square.stack.3d.down.right.fill")
            .accessibilityLabel("\(summary.visibleCount) of \(summary.totalCount) torrents shown")
            .padding(Self.rectanglePadding)
            .metricBackground()
    }

    private var speedLabels: some View {
        HStack(spacing: 12) {
            downloadSpeedLabel
            uploadSpeedLabel
        }
        .font(.body.monospacedDigit())
        .padding(Self.rectanglePadding)
        .metricBackground()
    }

    @ViewBuilder
    private var primarySpeedLabel: some View {
        Group {
            if summary.downloadSpeed >= summary.uploadSpeed {
                downloadSpeedLabel
            } else {
                uploadSpeedLabel
            }
        }
        .font(.body.monospacedDigit())
        .padding(Self.rectanglePadding)
        .metricBackground()
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

private extension View {

    func metricBackground() -> some View {
        self
            #if !os(macOS)
            .background(Color.secondary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            #endif
    }
}

struct ServerStatusView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerStatusView(summary: .init(
            visibleCount: 2,
            totalCount: 3,
            downloadSpeed: PreviewMockData.remoteTorrent.downloadRate,
            uploadSpeed: PreviewMockData.remoteTorrent.uploadRate
        ))
    }
}
