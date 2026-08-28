//
//  TorrentListView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

@MainActor
final class TorrentListState: ObservableObject {

    @Published fileprivate var torrents: [RemoteTorrent] = []
    @Published fileprivate var hasLoaded = false
    @Published fileprivate var isRefreshing = false
    @Published fileprivate var refreshErrorMessage: String?
    @Published fileprivate var refreshRequest = 0

    init(
        torrents: [RemoteTorrent] = [],
        hasLoaded: Bool = false,
        isRefreshing: Bool = false,
        refreshErrorMessage: String? = nil
    ) {
        self.torrents = torrents
        self.hasLoaded = hasLoaded
        self.isRefreshing = isRefreshing
        self.refreshErrorMessage = refreshErrorMessage
    }
}

struct TorrentListView: View {
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var actionController: TorrentActionController
    @StateObject private var listState: TorrentListState
    #if os(tvOS)
    @FocusState private var focusedTorrentID: String?
    #endif

    private struct PollingTaskID: Equatable {

        let serverID: UUID?
        let connectionDetails: ConnectionDetails?
        let refreshInterval: Int
        let isActive: Bool
        let refreshRequest: Int
    }
    
    @Binding var server: Server?
    @Binding var filter: Filter?
    @Binding var filterQuery: String
    @Binding var sort: TorrentSort
    @Binding var sortDirection: TorrentSortDirection
    @Binding var selectedTorrentId: String?

    let onSnapshotChange: ([RemoteTorrent]) -> Void
    let automaticallyPolls: Bool
    let usesListSelection: Bool
    
    #if os(watchOS)
    let refreshInterval: Int = 10
    #else
    @AppStorage(Constants.StorageKeys.autoUpdateInterval) var refreshInterval: Int = 2
    #endif

    init(
        server: Binding<Server?>,
        filter: Binding<Filter?>,
        filterQuery: Binding<String>,
        sort: Binding<TorrentSort>,
        sortDirection: Binding<TorrentSortDirection>,
        selectedTorrentId: Binding<String?>,
        actionController: TorrentActionController? = nil,
        listState: TorrentListState? = nil,
        automaticallyPolls: Bool = true,
        usesListSelection: Bool = true,
        onSnapshotChange: @escaping ([RemoteTorrent]) -> Void = { _ in }
    ) {
        self._server = server
        self._filter = filter
        self._filterQuery = filterQuery
        self._sort = sort
        self._sortDirection = sortDirection
        self._selectedTorrentId = selectedTorrentId
        self._actionController = StateObject(wrappedValue: actionController ?? TorrentActionController())
        self._listState = StateObject(wrappedValue: listState ?? TorrentListState())
        self.automaticallyPolls = automaticallyPolls
        self.usesListSelection = usesListSelection
        self.onSnapshotChange = onSnapshotChange
    }
    
    private var pollingTaskID: PollingTaskID {
        .init(
            serverID: server?.id,
            connectionDetails: server?.connectionDetails,
            refreshInterval: refreshInterval,
            isActive: automaticallyPolls && scenePhase == .active,
            refreshRequest: listState.refreshRequest
        )
    }

    private var projection: TorrentListProjection {
        TorrentListProjection(
            torrents: listState.torrents,
            filter: filter,
            query: filterQuery,
            sort: sort,
            sortDirection: sortDirection
        )
    }

    private var presentationState: TorrentListPresentationState {
        TorrentListPresentationState(
            hasServer: server != nil,
            hasLoaded: listState.hasLoaded,
            isRefreshing: listState.isRefreshing,
            refreshError: listState.refreshErrorMessage,
            projection: projection
        )
    }

    private var listSelection: Binding<String?>? {
        #if os(iOS)
        usesListSelection ? $selectedTorrentId : nil
        #else
        $selectedTorrentId
        #endif
    }

    private func requestRefresh() {
        listState.refreshRequest += 1
    }

    private func clearData() {
        listState.torrents = []
        listState.hasLoaded = false
        listState.isRefreshing = false
        listState.refreshErrorMessage = nil
        onSnapshotChange([])
        selectedTorrentId = nil
    }

    private func pollTorrents() async {
        guard automaticallyPolls else {
            return
        }
        guard scenePhase == .active else {
            return
        }

        guard let server else {
            clearData()
            return
        }

        let serverID = server.id
        let connection = server.connection

        while !Task.isCancelled {
            listState.isRefreshing = true

            do {
                let updatedTorrents = try await connection.getTorrents()
                try Task.checkCancellation()

                guard self.server?.id == serverID else {
                    return
                }

                listState.torrents = updatedTorrents
                actionController.reconcileFailures(
                    with: updatedTorrents,
                    serverID: serverID
                )
                listState.hasLoaded = true
                listState.isRefreshing = false
                listState.refreshErrorMessage = nil
                onSnapshotChange(updatedTorrents)
            } catch is CancellationError {
                return
            } catch {
                guard self.server?.id == serverID else {
                    return
                }

                listState.isRefreshing = false
                listState.refreshErrorMessage = error.localizedDescription
            }

            guard let pollingInterval = PollingInterval.timeInterval(for: refreshInterval) else {
                return
            }

            do {
                try await Task.sleep(for: .seconds(pollingInterval))
            } catch {
                return
            }
        }
    }
    
    #if os(iOS)
    static private let listStyle = InsetGroupedListStyle()
    #else
    static private let listStyle = DefaultListStyle()
    #endif

    private var actionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { actionController.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    actionController.clearAlertFailure()
                }
            }
        )
    }

    @ViewBuilder
    private func actionButtons(for torrent: RemoteTorrent) -> some View {
        switch torrent.primaryAction {
        case .start:
            Button {
                perform(.start, on: torrent)
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .disabled(isPerformingAction(on: torrent))
        case .stop:
            Button {
                perform(.stop, on: torrent)
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .disabled(isPerformingAction(on: torrent))
        case .remove, .none:
            EmptyView()
        }
    }

    private func isPerformingAction(on torrent: RemoteTorrent) -> Bool {
        guard let server else {
            return false
        }
        return actionController.isPerformingAction(on: torrent, server: server)
    }

    private func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) {
        guard let server else {
            return
        }
        actionController.perform(action, on: torrent, server: server)
    }

    @ViewBuilder
    private func torrentRow(_ torrent: RemoteTorrent, server: Server) -> some View {
        #if os(macOS)
        NavigationLink(value: torrent.id) {
            TorrentItemView(torrent: torrent, isPerformingAction: isPerformingAction(on: torrent))
                .padding(.vertical, 8)
                .padding(.horizontal, 5)
        }
        .contextMenu {
            actionButtons(for: torrent)
        }
        .accessibilityIdentifier("torrent-row-\(torrent.id)")
        #elseif os(iOS)
        NavigationLink(value: torrent.id) {
            TorrentItemView(torrent: torrent, isPerformingAction: isPerformingAction(on: torrent))
                .padding(.vertical, 8)
                .padding(.horizontal, 5)
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .swipeActions(edge: .trailing) {
            actionButtons(for: torrent)
                .tint(.accentColor)
        }
        .accessibilityIdentifier("torrent-row-\(torrent.id)")
        #else
        NavigationLink(
            destination: TorrentDetailsViewWrapper(
                torrent: torrent,
                server: server,
                actionController: actionController
            )
        ) {
            TorrentItemView(torrent: torrent, isPerformingAction: isPerformingAction(on: torrent))
                .padding(.vertical, 8)
                .padding(.horizontal, 5)
        }
        #if os(tvOS)
        .focused($focusedTorrentID, equals: torrent.id)
        .contextMenu {
            actionButtons(for: torrent)
        }
        #endif
        .accessibilityIdentifier("torrent-row-\(torrent.id)")
        #endif
    }

    @ViewBuilder
    private func refreshStatus(isRefreshing: Bool, errorMessage: String?) -> some View {
        if let errorMessage {
            if isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                    Text("Retrying")
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading torrents")
                .accessibilityValue("Retry in progress")
                .font(.footnote)
                .padding(.vertical, 8)
            } else {
                Button {
                    requestRefresh()
                } label: {
                    Label("Showing previous results. Retry", systemImage: "exclamationmark.arrow.circlepath")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Retry loading torrents")
                .accessibilityValue("Showing previous results")
                .accessibilityHint(errorMessage)
                .font(.footnote)
                .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func serverSummary(_ summary: TorrentListSummary) -> some View {
        #if os(watchOS)
        ServerStatusView(summary: summary)
        #elseif os(iOS)
        if #unavailable(iOS 26.1) {
            ServerStatusView(summary: summary)
        }
        #else
        ServerStatusView(summary: summary)
        #endif
    }

    private func loadedView<Content: View>(
        projection: TorrentListProjection,
        isRefreshing: Bool,
        refreshError: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            refreshStatus(isRefreshing: isRefreshing, errorMessage: refreshError)

            #if os(watchOS)
            content()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    serverSummary(projection.summary)
                }
            #elseif os(iOS)
            if #available(iOS 26.1, *) {
                content()
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        FloatingServerStatusView(summary: projection.summary)
                    }
            } else {
                content()
                serverSummary(projection.summary)
            }
            #elseif os(macOS)
            content()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    serverSummary(projection.summary)
                }
            #else
            content()
            serverSummary(projection.summary)
            #endif
        }
    }

    private func initialErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            ErrorView(type: .noConnection)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: requestRefresh) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .padding(.bottom)
        }
    }
    
    var body: some View {
        Group {
            switch presentationState {
            case .noServer:
                NoServersConfiguredView()

            case .initialError(let message):
                ScrollView {
                    initialErrorView(message)
                }
                
            case .initialLoading:
                LoadingView()

            case let .empty(isRefreshing, refreshError):
                loadedView(
                    projection: projection,
                    isRefreshing: isRefreshing,
                    refreshError: refreshError
                ) {
                    TorrentListUnavailableView(
                        title: "No Torrents",
                        description: "This server does not contain any torrents.",
                        systemImage: "tray"
                    )
                }

            case let .noResults(projection, isRefreshing, refreshError):
                loadedView(
                    projection: projection,
                    isRefreshing: isRefreshing,
                    refreshError: refreshError
                ) {
                    TorrentListUnavailableView(
                        title: "Nothing Matches",
                        description: "Try another search or status filter.",
                        systemImage: "line.3.horizontal.decrease.circle"
                    ) {
                        if !filterQuery.isEmpty {
                            Button("Clear Search") {
                                filterQuery = ""
                            }
                        }
                        if filter != nil {
                            Button("Clear Filter") {
                                filter = nil
                            }
                        }
                    }
                }

            case let .content(projection, isRefreshing, refreshError):
                loadedView(
                    projection: projection,
                    isRefreshing: isRefreshing,
                    refreshError: refreshError
                ) {
                    List(selection: listSelection) {
                        ForEach(projection.torrents) { torrent in
                            if let server {
                                torrentRow(torrent, server: server)
                            }
                        }
                    }
                    #if os(iOS)
                    .contentMargins(.top, 0, for: .scrollContent)
                    .tint(usesListSelection ? .gray : nil)
                    #endif
                    .listStyle(Self.listStyle)
                }
            }
        }
        .onChange(of: server) { oldServer, newServer in
            if oldServer?.id != newServer?.id
                || oldServer?.connectionDetails != newServer?.connectionDetails {
                clearData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateTorrentListView)) { _ in
            requestRefresh()
        }
        .task(id: pollingTaskID) {
            await pollTorrents()
        }
        .onAppear {
            onSnapshotChange(listState.torrents)
            #if os(tvOS)
            if focusedTorrentID == nil {
                focusedTorrentID = projection.torrents.first?.id
            }
            #endif
        }
        #if os(tvOS)
        .onChange(of: projection.torrents.map(\.id)) { _, torrentIDs in
            if focusedTorrentID == nil || !torrentIDs.contains(focusedTorrentID ?? "") {
                focusedTorrentID = torrentIDs.first
            }
        }
        #endif
        .alert("Torrent Action Failed", isPresented: actionErrorIsPresented) {
            Button("OK", role: .cancel) {
                actionController.clearAlertFailure()
            }
        } message: {
            Text(actionController.errorMessage ?? "The action could not be completed.")
        }
    }
}

private struct TorrentListUnavailableView<Actions: View>: View {

    let title: String
    let description: String
    let systemImage: String
    @ViewBuilder let actions: Actions

    init(
        title: String,
        description: String,
        systemImage: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Image(systemName: systemImage)
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(description)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            actions
                        }
                        VStack {
                            actions
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension TorrentListUnavailableView where Actions == EmptyView {

    init(title: String, description: String, systemImage: String) {
        self.init(title: title, description: description, systemImage: systemImage) {
            EmptyView()
        }
    }
}

struct TorrentListView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentListStatePreview(
                state: TorrentListState(),
                includesServer: false
            )
            .previewDisplayName("No Server")

            TorrentListStatePreview(state: TorrentListState())
                .previewDisplayName("Initial Loading")

            TorrentListStatePreview(
                state: TorrentListState(
                    refreshErrorMessage: "The local server could not be reached. Check Local Network access and retry."
                )
            )
            .previewDisplayName("Initial Error")

            TorrentListStatePreview(
                state: TorrentListState(
                    isRefreshing: true,
                    refreshErrorMessage: "Retrying the initial request."
                )
            )
            .previewDisplayName("Initial Retry")

            TorrentListStatePreview(
                state: TorrentListState(hasLoaded: true)
            )
            .previewDisplayName("Empty Server")

            TorrentListStatePreview(
                state: TorrentListState(
                    torrents: PreviewMockData.remoteTorrents,
                    hasLoaded: true
                ),
                query: "No matching torrent"
            )
            .previewDisplayName("No Results")

            TorrentListStatePreview(
                state: TorrentListState(
                    torrents: PreviewMockData.remoteTorrents,
                    hasLoaded: true
                )
            )
                .previewDisplayName("Loaded")

            TorrentListStatePreview(
                state: TorrentListState(
                    torrents: PreviewMockData.remoteTorrents,
                    hasLoaded: true,
                    refreshErrorMessage: "A deliberately long stale-data error verifies that Retry remains understandable."
                )
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Stale Error - Dark")

            TorrentListStatePreview(
                state: TorrentListState(
                    torrents: PreviewMockData.remoteTorrents,
                    hasLoaded: true,
                    isRefreshing: true,
                    refreshErrorMessage: "Retrying after a connection failure."
                )
            )
            .environment(\.dynamicTypeSize, .accessibility3)
            .previewDisplayName("Retrying - Accessibility Text")
        }
        #if os(iOS)
        .previewDevice("iPhone 16 Pro")
        #endif
    }
}

private struct TorrentListStatePreview: View {

    @State private var server: Server?
    @State private var filter: Filter?
    @State private var query: String
    @State private var sort: TorrentSort = .activity
    @State private var sortDirection: TorrentSortDirection = .ascending
    @State private var selectedTorrentID: String?

    let state: TorrentListState

    init(
        state: TorrentListState,
        includesServer: Bool = true,
        filter: Filter? = nil,
        query: String = ""
    ) {
        self.state = state
        self._server = State(initialValue: includesServer ? PreviewMockData.settingsServer : nil)
        self._filter = State(initialValue: filter)
        self._query = State(initialValue: query)
    }

    var body: some View {
        TorrentListView(
            server: $server,
            filter: $filter,
            filterQuery: $query,
            sort: $sort,
            sortDirection: $sortDirection,
            selectedTorrentId: $selectedTorrentID,
            listState: state,
            automaticallyPolls: false
        )
    }
}
