//
//  FloatingServerStatusView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

@available(iOS 26.0, *)
struct FloatingServerStatusView: View {
    
    let summary: TorrentListSummary
    
    static private let rectanglePadding: CGFloat = 5
    
    var body: some View {
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
        .padding(.horizontal)
        .padding(.vertical, 5)
        .glassEffect()
        .padding(.horizontal)
        .padding(.bottom, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.visibleCount) of \(summary.totalCount) torrents shown")
        .accessibilityValue(
            "Download speed \(downloadSpeed), upload speed \(uploadSpeed)"
        )
    }

    private var countLabel: some View {
        Label(summary.countLabel, systemImage: "square.stack.3d.down.right.fill")
            .labelStyle(.titleAndIcon)
            .accessibilityLabel("\(summary.visibleCount) of \(summary.totalCount) torrents shown")
            .padding(Self.rectanglePadding)
    }

    private var speedLabels: some View {
        HStack(spacing: 12) {
            downloadSpeedLabel
            uploadSpeedLabel
        }
        .labelStyle(.titleAndIcon)
        .font(.body.monospacedDigit())
        .padding(Self.rectanglePadding)
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
        .labelStyle(.titleAndIcon)
        .font(.body.monospacedDigit())
        .padding(Self.rectanglePadding)
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

@available(iOS 26.0, *)
struct FloatingServerStatusView_Previews: PreviewProvider {
    
    static var previews: some View {
        FloatingServerStatusLayoutPreview()
            .previewDevice("iPhone 16 Pro")
    }
}

@available(iOS 26.0, *)
private struct FloatingServerStatusLayoutPreview: View {

    @State private var query = ""

    private var projection: TorrentListProjection {
        TorrentListProjection(
            torrents: PreviewMockData.remoteTorrents,
            filter: nil,
            query: query,
            sort: .activity,
            sortDirection: .ascending
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                List(projection.torrents) { torrent in
                    TorrentItemView(torrent: torrent)
                }
                .contentMargins(.top, 0, for: .scrollContent)
                .listStyle(.insetGrouped)
                .navigationTitle("Torrents")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search torrents"
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    FloatingServerStatusView(summary: projection.summary)
                }
            }
                .tabItem {
                    Label("Torrents", systemImage: "tray.and.arrow.down")
                }
        }
    }
}
