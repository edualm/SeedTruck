//
//  TorrentDetailsPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation

struct TorrentActionIdentifier: Hashable, Sendable {

    let serverID: UUID
    let torrentID: String
}

struct TorrentActionFailure: Equatable, Sendable {

    let action: RemoteTorrent.Action
    let message: String
}

@MainActor
final class TorrentActionController: ObservableObject {

    @Published private(set) var activeActionIDs: Set<TorrentActionIdentifier> = []
    @Published private(set) var failures: [TorrentActionIdentifier: TorrentActionFailure] = [:]
    @Published private(set) var errorMessage: String?

    private var alertFailureID: TorrentActionIdentifier?

    init(
        activeActionIDs: Set<TorrentActionIdentifier> = [],
        failures: [TorrentActionIdentifier: TorrentActionFailure] = [:]
    ) {
        self.activeActionIDs = activeActionIDs
        self.failures = failures
    }

    func isPerformingAction(on torrent: RemoteTorrent, server: Server) -> Bool {
        activeActionIDs.contains(actionIdentifier(for: torrent, server: server))
    }

    func failure(on torrent: RemoteTorrent, server: Server) -> TorrentActionFailure? {
        failures[actionIdentifier(for: torrent, server: server)]
    }

    func clearAlertFailure() {
        if let alertFailureID {
            failures.removeValue(forKey: alertFailureID)
        }
        alertFailureID = nil
        errorMessage = nil
    }

    func reconcileFailures(with torrents: [RemoteTorrent], serverID: UUID) {
        let torrentsByID = Dictionary(uniqueKeysWithValues: torrents.map { ($0.id, $0) })
        let resolvedFailureIDs = failures.compactMap { identifier, failure -> TorrentActionIdentifier? in
            guard identifier.serverID == serverID else {
                return nil
            }

            switch failure.action {
            case .start:
                return torrentsByID[identifier.torrentID]?.primaryAction == .stop ? identifier : nil
            case .stop:
                return torrentsByID[identifier.torrentID]?.status == .stopped ? identifier : nil
            case .remove:
                return torrentsByID[identifier.torrentID] == nil ? identifier : nil
            }
        }

        for identifier in resolvedFailureIDs {
            failures.removeValue(forKey: identifier)
            if alertFailureID == identifier {
                alertFailureID = nil
                errorMessage = nil
            }
        }
    }

    func perform(
        _ action: RemoteTorrent.Action,
        on torrent: RemoteTorrent,
        server: Server,
        showsErrorAlert: Bool = true,
        onSuccess: (() -> Void)? = nil
    ) {
        perform(
            action,
            on: torrent,
            identifier: actionIdentifier(for: torrent, server: server),
            connection: server.connection,
            showsErrorAlert: showsErrorAlert,
            onSuccess: onSuccess
        )
    }

    func perform(
        _ action: RemoteTorrent.Action,
        on torrent: RemoteTorrent,
        identifier: TorrentActionIdentifier,
        connection: any ServerConnection,
        showsErrorAlert: Bool = true,
        onSuccess: (() -> Void)? = nil
    ) {
        guard activeActionIDs.insert(identifier).inserted else {
            return
        }
        failures.removeValue(forKey: identifier)
        if showsErrorAlert, alertFailureID == identifier {
            alertFailureID = nil
            errorMessage = nil
        }

        Task {
            do {
                try await connection.perform(action, on: torrent)

                activeActionIDs.remove(identifier)
                failures.removeValue(forKey: identifier)
                NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
                onSuccess?()
            } catch {
                activeActionIDs.remove(identifier)
                failures[identifier] = .init(
                    action: action,
                    message: error.localizedDescription
                )
                if showsErrorAlert {
                    alertFailureID = identifier
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func actionIdentifier(for torrent: RemoteTorrent, server: Server) -> TorrentActionIdentifier {
        TorrentActionIdentifier(
            serverID: server.id,
            torrentID: torrent.id
        )
    }
}

@MainActor
final class TorrentDetailsPresenter: ObservableObject {

    let actionController: TorrentActionController

    @Published var pendingRemoval: TorrentRemovalConfirmation?

    init(actionController: TorrentActionController) {
        self.actionController = actionController
    }

    func performPrimaryAction(on torrent: RemoteTorrent, server: Server) {
        guard let action = torrent.primaryAction else {
            return
        }
        actionController.perform(
            action,
            on: torrent,
            server: server,
            showsErrorAlert: false
        )
    }

    func prepareRemoval(_ policy: RemoteTorrent.RemovalPolicy, from torrent: RemoteTorrent) {
        pendingRemoval = TorrentRemovalConfirmation(torrent: torrent, policy: policy)
    }

    func confirmRemoval(
        _ policy: RemoteTorrent.RemovalPolicy,
        from torrent: RemoteTorrent,
        server: Server,
        onSuccess: @escaping () -> Void
    ) {
        pendingRemoval = nil
        actionController.perform(
            .remove(policy),
            on: torrent,
            server: server,
            showsErrorAlert: false,
            onSuccess: onSuccess
        )
    }

    func retryFailedAction(
        on torrent: RemoteTorrent,
        server: Server,
        onRemovalSuccess: @escaping () -> Void
    ) {
        guard let failure = actionController.failure(on: torrent, server: server) else {
            return
        }

        let onSuccess: (() -> Void)?
        switch failure.action {
        case .remove:
            onSuccess = onRemovalSuccess
        case .start, .stop:
            onSuccess = nil
        }

        actionController.perform(
            failure.action,
            on: torrent,
            server: server,
            showsErrorAlert: false,
            onSuccess: onSuccess
        )
    }
}
