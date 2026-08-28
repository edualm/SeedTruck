//
//  TorrentItemView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentItemView: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var progressHeight: CGFloat = 20
    
    struct SpeedView: View {
        
        let torrent: RemoteTorrent
        
        @ViewBuilder
        var body: some View {
            if torrent.downloadRate == 0 && torrent.uploadRate == 0 {
                EmptyView()
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if torrent.downloadRate > 0 {
                        Label(
                            ByteCountFormatter.humanReadableTransferRate(
                                bytesPerSecond: torrent.downloadRate
                            ),
                            systemImage: "arrow.down.forward"
                        )
                        .labelStyle(CompactLabelStyle())
                        .font(.footnote.monospacedDigit())
                    }

                    if torrent.uploadRate > 0 {
                        Label(
                            ByteCountFormatter.humanReadableTransferRate(
                                bytesPerSecond: torrent.uploadRate
                            ),
                            systemImage: "arrow.up.forward"
                        )
                        .labelStyle(CompactLabelStyle())
                        .font(.footnote.monospacedDigit())
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(.secondary)
            }
        }
    }

    #if os(watchOS)
    private struct CompactSpeedView: View {

        let torrent: RemoteTorrent

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if torrent.downloadRate > 0 {
                    Label(
                        ByteCountFormatter.humanReadableCompactTransferRate(
                            bytesPerSecond: torrent.downloadRate
                        ),
                        systemImage: "arrow.down.forward"
                    )
                    .labelStyle(CompactLabelStyle(spacing: 2))
                }

                if torrent.uploadRate > 0 {
                    Label(
                        ByteCountFormatter.humanReadableCompactTransferRate(
                            bytesPerSecond: torrent.uploadRate
                        ),
                        systemImage: "arrow.up.forward"
                    )
                    .labelStyle(CompactLabelStyle(spacing: 2))
                }
            }
            .font(.caption2.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.secondary)
        }
    }
    #endif
    
    var torrent: RemoteTorrent
    var isPerformingAction = false

    private var statusColor: Color {
        switch torrent.status {
        case .stopped:
            return .secondary
        case .queuedForDownload, .downloading:
            return .blue
        case .queuedForSeed, .seeding:
            return .green
        case .queuedForCheck, .checking:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var accessibilityValue: String {
        var values = [
            torrent.status.displayableStatus,
            "\(torrent.detailProgress.label), \(String(format: "%.0f percent", torrent.detailProgress.fraction * 100))"
        ]
        if torrent.downloadRate > 0 {
            values.append("download speed \(ByteCountFormatter.humanReadableTransferRate(bytesPerSecond: torrent.downloadRate))")
        }
        if torrent.uploadRate > 0 {
            values.append("upload speed \(ByteCountFormatter.humanReadableTransferRate(bytesPerSecond: torrent.uploadRate))")
        }
        if isPerformingAction {
            values.append("action in progress")
        }
        return values.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(torrent.name)
                .bold()
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: {
                switch torrent.status {
                case .stopped:
                    return Color.secondary
                case .queuedForCheck, .checking:
                    return Color.orange
                case .unknown:
                    return Color.secondary
                default:
                    #if os(macOS)
                    return $0 < 1 ? Color.blue.opacity(0.8) : Color.green.opacity(0.8)
                    #else
                    return $0 < 1 ? .blue : .green
                    #endif
                }
            }, progress: CGFloat(torrent.detailProgress.fraction))
                .frame(height: progressHeight)

            metadataFooter
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(torrent.name)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens torrent details")
    }

    @ViewBuilder
    private var metadataFooter: some View {
        #if os(watchOS)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                statusLabel
                if torrent.transferSpeed > 0 {
                    CompactSpeedView(torrent: torrent)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } else if torrent.transferSpeed > 0 {
            HStack(spacing: 6) {
                statusIcon
                Spacer(minLength: 6)
                CompactSpeedView(torrent: torrent)
            }
        } else {
            statusLabel
        }
        #else
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                statusLabel
                Spacer(minLength: 12)
                SpeedView(torrent: torrent)
            }

            VStack(alignment: .leading, spacing: 6) {
                statusLabel
                SpeedView(torrent: torrent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        #endif
    }

    private var statusIcon: some View {
        Image(systemName: torrent.status.systemImage)
            .foregroundStyle(statusColor)
            .font(.footnote)
    }

    private var statusLabel: some View {
        Label {
            Text(torrent.status.displayableStatus)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: torrent.status.systemImage)
                .foregroundStyle(statusColor)
        }
        .labelStyle(CompactLabelStyle())
        .font(.footnote)
    }
}

struct TorrentItemView_Previews: PreviewProvider {
    
    static var previews: some View {
        #if os(watchOS)
        Group {
            TorrentItemView(torrent: PreviewMockData.remoteTorrent)
                .padding(8)
                .previewDisplayName("Active transfers")

            TorrentItemView(torrent: PreviewMockData.remoteTorrents[0])
                .padding(8)
                .previewDisplayName("Idle")

            TorrentItemView(torrent: PreviewMockData.remoteTorrent)
                .padding(8)
                .environment(\.dynamicTypeSize, .accessibility2)
                .previewDisplayName("Accessibility text")
        }
        .previewLayout(.fixed(width: 176, height: 145))
        #else
        ForEach(PreviewMockData.remoteTorrents) { torrent in
            TorrentItemView(torrent: torrent)
                .padding()
                .previewDisplayName(torrent.status.displayableStatus)
        }
        .previewLayout(.fixed(width: 400, height: 130))
        #endif
    }
}
