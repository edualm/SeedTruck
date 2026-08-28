//
//  TorrentDetailsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentDetailsViewWrapper: View {

    let torrent: RemoteTorrent
    let server: Server
    let onRemovalCompleted: () -> Void

    @StateObject private var presenter: TorrentDetailsPresenter
    @State private var displayedTorrent: RemoteTorrent
    @State private var refreshRequest = 0

    private struct RefreshTaskID: Equatable {

        let serverID: UUID
        let connectionDetails: ConnectionDetails
        let torrentID: String
        let refreshRequest: Int
    }

    init(
        torrent: RemoteTorrent,
        server: Server,
        actionController: TorrentActionController? = nil,
        onRemovalCompleted: @escaping () -> Void = {}
    ) {
        let controller = actionController ?? TorrentActionController()
        self.torrent = torrent
        self.server = server
        self.onRemovalCompleted = onRemovalCompleted
        self._displayedTorrent = State(initialValue: torrent)
        self._presenter = StateObject(
            wrappedValue: TorrentDetailsPresenter(actionController: controller)
        )
    }

    private var refreshTaskID: RefreshTaskID {
        .init(
            serverID: server.id,
            connectionDetails: server.connectionDetails,
            torrentID: torrent.id,
            refreshRequest: refreshRequest
        )
    }

    private func refreshTorrent() async {
        let torrentID = torrent.id
        let connection = server.connection

        guard let refreshedTorrent = try? await connection.getTorrent(id: torrentID),
              !Task.isCancelled,
              refreshedTorrent.id == torrentID else {
            return
        }

        displayedTorrent = refreshedTorrent
    }

    var body: some View {
        TorrentDetailsView(
            torrent: displayedTorrent,
            server: server,
            onRemovalCompleted: onRemovalCompleted,
            presenter: presenter,
            actionController: presenter.actionController
        )
        .onChange(of: torrent) { _, updatedTorrent in
            displayedTorrent = updatedTorrent
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateTorrentListView)) { _ in
            refreshRequest += 1
        }
        .task(id: refreshTaskID) {
            await refreshTorrent()
        }
    }
}

struct TorrentDetailsView: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var progressHeight: CGFloat = 18
    @AccessibilityFocusState private var failureIsFocused: Bool

    private struct SectionCard<Content: View>: View {

        let title: String
        let systemImage: String
        @ViewBuilder let content: Content

        init(
            title: String,
            systemImage: String,
            @ViewBuilder content: () -> Content
        ) {
            self.title = title
            self.systemImage = systemImage
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private struct MetricCard: View {

        let metric: TorrentDetailMetric

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Label(metric.label, systemImage: metric.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    #if os(watchOS)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    #endif

                Text(metric.value)
                    .font(.headline.monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(metric.label)
            .accessibilityValue(metric.value)
        }
    }

    @Environment(\.dismiss) private var dismiss

    let torrent: RemoteTorrent
    let server: Server
    let onRemovalCompleted: () -> Void

    @ObservedObject var presenter: TorrentDetailsPresenter
    @ObservedObject var actionController: TorrentActionController

    private var projection: TorrentDetailProjection {
        TorrentDetailProjection(torrent: torrent)
    }

    private var isPerformingAction: Bool {
        actionController.isPerformingAction(on: torrent, server: server)
    }

    private var actionFailure: TorrentActionFailure? {
        actionController.failure(on: torrent, server: server)
    }

    private var statusColor: Color {
        switch torrent.status {
        case .stopped:
            return .secondary
        case .queuedForCheck, .checking, .queuedForDownload, .queuedForSeed:
            return .orange
        case .downloading:
            return .blue
        case .seeding:
            return .green
        case .unknown:
            return .secondary
        }
    }

    private var metricColumns: [GridItem] {
        #if os(watchOS)
        [GridItem(.flexible())]
        #elseif os(tvOS)
        [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 16)]
        #else
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 12)]
        #endif
    }

    private func completeRemoval() {
        onRemovalCompleted()
        dismiss()
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if let action = projection.primaryAction {
            Button {
                presenter.performPrimaryAction(on: torrent, server: server)
            } label: {
                HStack(spacing: 8) {
                    if isPerformingAction {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: action.systemImage)
                    }
                    Text(action.displayName)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPerformingAction)
            .accessibilityValue(isPerformingAction ? "In progress" : "")
        }
    }

    private var summaryHeader: some View {
        SectionCard(title: "Overview", systemImage: "doc.text.magnifyingglass") {
            VStack(alignment: .leading, spacing: 14) {
                Text(torrent.name)
                    #if os(watchOS)
                    .font(.headline)
                    #else
                    .font(.title2.bold())
                    #endif
                    .fixedSize(horizontal: false, vertical: true)

                Label(projection.statusText, systemImage: projection.statusSystemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)

                ProgressBarView(
                    cornerRadius: 9,
                    barColorBuilder: { progress in
                        if projection.progress.kind == .verification {
                            return .orange
                        }
                        return progress < 1 ? .blue : .green
                    },
                    progress: CGFloat(projection.progress.fraction),
                    accessibilityTitle: projection.progress.label
                )
                .frame(height: progressHeight)

                if let etaLabel = projection.etaLabel {
                    HStack(alignment: .firstTextBaseline) {
                        Label(etaLabel, systemImage: "clock")
                        Spacer()
                        Text(projection.etaText)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(etaLabel)
                    .accessibilityValue(projection.etaText)
                }

                primaryActionButton
            }
        }
    }

    @ViewBuilder
    private var failureView: some View {
        if let failure = actionFailure {
            SectionCard(title: "Action Failed", systemImage: "exclamationmark.triangle.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        presenter.retryFailedAction(
                            on: torrent,
                            server: server,
                            onRemovalSuccess: completeRemoval
                        )
                    } label: {
                        Label("Retry \(failure.action.displayName)", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPerformingAction)
                    .accessibilityValue(isPerformingAction ? "In progress" : "")
                }
            }
            .accessibilityFocused($failureIsFocused)
        }
    }

    private var metricsGrid: some View {
        SectionCard(title: "Activity", systemImage: "gauge.with.dots.needle.50percent") {
            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                ForEach(projection.metrics) { metric in
                    MetricCard(metric: metric)
                }
            }
        }
    }

    private var removalSection: some View {
        SectionCard(title: "Removal", systemImage: "trash") {
            VStack(alignment: .leading, spacing: 12) {
                Button(role: .destructive) {
                    if !isPerformingAction {
                        presenter.prepareRemoval(.keepLocalData, from: torrent)
                    }
                } label: {
                    Label("Remove Torrent and Keep Files", systemImage: "externaldrive.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPerformingAction)
                .accessibilityValue(isPerformingAction ? "Another action is in progress" : "")

                Button(role: .destructive) {
                    if !isPerformingAction {
                        presenter.prepareRemoval(.deleteLocalData, from: torrent)
                    }
                } label: {
                    Label("Remove Torrent and Delete Files", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isPerformingAction)
                .accessibilityValue(isPerformingAction ? "Another action is in progress" : "")
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryHeader
                failureView
                metricsGrid
                removalSection
            }
            #if os(watchOS)
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
            #else
            .padding()
            #endif
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Torrent Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert(item: $presenter.pendingRemoval) { confirmation in
            Alert(
                title: Text(confirmation.title),
                message: Text(confirmation.message),
                primaryButton: .destructive(Text(confirmation.confirmButtonTitle)) {
                    presenter.confirmRemoval(
                        confirmation.id,
                        from: torrent,
                        server: server,
                        onSuccess: completeRemoval
                    )
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: actionFailure) { _, failure in
            failureIsFocused = failure != nil
        }
        .onAppear {
            failureIsFocused = actionFailure != nil
        }
    }
}

struct TorrentDetailsView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            ForEach(PreviewMockData.remoteTorrents) { torrent in
                TorrentDetailsViewWrapper(
                    torrent: torrent,
                    server: PreviewMockData.server
                )
                .previewDisplayName(torrent.status.displayableStatus)
            }

            TorrentDetailsStatePreview(state: .failure)
                .preferredColorScheme(.dark)
                .previewDisplayName("Action Failure - Dark")

            TorrentDetailsStatePreview(state: .busy)
                .environment(\.dynamicTypeSize, .accessibility3)
                .previewDisplayName("Busy - Accessibility Text")
        }
    }
}

private struct TorrentDetailsStatePreview: View {

    enum State {
        case busy
        case failure
    }

    private let server: Server?
    @StateObject private var actionController: TorrentActionController

    init(state: State) {
        let server = PreviewMockData.settingsServer
        self.server = server

        guard let server else {
            self._actionController = StateObject(wrappedValue: TorrentActionController())
            return
        }

        let identifier = TorrentActionIdentifier(
            serverID: server.id,
            torrentID: PreviewMockData.remoteTorrent.id
        )
        switch state {
        case .busy:
            self._actionController = StateObject(
                wrappedValue: TorrentActionController(activeActionIDs: [identifier])
            )
        case .failure:
            self._actionController = StateObject(
                wrappedValue: TorrentActionController(
                    failures: [
                        identifier: TorrentActionFailure(
                            action: .stop,
                            message: "The local server rejected the request after a long-running connection attempt. Check its availability and retry."
                        )
                    ]
                )
            )
        }
    }

    var body: some View {
        if let server {
            NavigationStack {
                TorrentDetailsViewWrapper(
                    torrent: PreviewMockData.remoteTorrent,
                    server: server,
                    actionController: actionController
                )
            }
        } else {
            Text("Preview server unavailable")
        }
    }
}
