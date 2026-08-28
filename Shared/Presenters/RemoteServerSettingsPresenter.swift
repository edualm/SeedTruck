//
//  RemoteServerSettingsPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 04/10/2021.
//

import Foundation

@MainActor
final class RemoteServerSettingsPresenter: ObservableObject {

    enum SpeedLimit {

        struct Configuration: Equatable {

            var down: Int
            var up: Int
        }

        struct State: Equatable {

            var down: Bool
            var up: Bool
        }
    }

    let server: Server
    private let connection: any ServerConnection

    private var savedSpeedLimitConfiguration: SpeedLimit.Configuration?
    private var savedSpeedLimitState: SpeedLimit.State?
    private var savedGlobalSpeedLimits: GlobalSpeedLimits?

    @Published var hasServerSupport: Bool = true
    @Published var isErrored: Bool = false
    @Published var isLoading: Bool = true
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    @Published var speedLimitConfiguration = SpeedLimit.Configuration(down: 0, up: 0)
    @Published var speedLimitState = SpeedLimit.State(down: false, up: false)

    var hasValidSpeedLimits: Bool {
        speedLimitConfiguration.down >= 0
            && speedLimitConfiguration.up >= 0
            && speedLimitConfiguration.down <= Int64.max / 1_000
            && speedLimitConfiguration.up <= Int64.max / 1_000
            && (!speedLimitState.down || speedLimitConfiguration.down > 0)
            && (!speedLimitState.up || speedLimitConfiguration.up > 0)
    }

    var hasChanges: Bool {
        guard let savedSpeedLimitConfiguration, let savedSpeedLimitState else {
            return false
        }

        return speedLimitConfiguration != savedSpeedLimitConfiguration
            || speedLimitState != savedSpeedLimitState
    }

    var canApplyChanges: Bool {
        hasValidSpeedLimits && hasChanges && !isLoading && !isSaving
    }

    init(server: Server, connection: (any ServerConnection)? = nil) {
        self.server = server
        self.connection = connection ?? server.connection

        Task {
            await acquireData()
        }
    }

    private func acquireData(showLoading: Bool = true) async {
        guard let connection = self.connection as? GlobalSpeedLimitSupporting else {
            hasServerSupport = false
            isLoading = false
            return
        }

        if showLoading {
            isLoading = true
        }
        isErrored = false
        errorMessage = nil

        do {
            let limits = try await connection.globalSpeedLimits()
            guard let downLimit = Self.displayedKilobytesPerSecond(
                    from: limits.download.bytesPerSecond
                  ),
                  let upLimit = Self.displayedKilobytesPerSecond(
                    from: limits.upload.bytesPerSecond
                  ) else {
                throw ServerCommunicationError.parseError
            }

            let configuration = SpeedLimit.Configuration(down: downLimit, up: upLimit)
            let state = SpeedLimit.State(
                down: limits.download.isEnabled,
                up: limits.upload.isEnabled
            )
            speedLimitConfiguration = configuration
            speedLimitState = state
            savedSpeedLimitConfiguration = configuration
            savedSpeedLimitState = state
            savedGlobalSpeedLimits = limits
            isLoading = false
        } catch {
            isErrored = true
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func retry() {
        guard !isLoading, !isSaving else {
            return
        }

        Task {
            await acquireData()
        }
    }

    func applyChanges() {
        guard !isLoading,
              !isSaving,
              hasValidSpeedLimits,
              hasChanges,
              let savedSpeedLimitConfiguration,
              let savedGlobalSpeedLimits,
              let connection = self.connection as? GlobalSpeedLimitSupporting else {
            return
        }

        let limits = GlobalSpeedLimits(
            download: .init(
                bytesPerSecond: speedLimitConfiguration.down == savedSpeedLimitConfiguration.down
                    ? savedGlobalSpeedLimits.download.bytesPerSecond
                    : Int64(speedLimitConfiguration.down) * 1_000,
                isEnabled: speedLimitState.down
            ),
            upload: .init(
                bytesPerSecond: speedLimitConfiguration.up == savedSpeedLimitConfiguration.up
                    ? savedGlobalSpeedLimits.upload.bytesPerSecond
                    : Int64(speedLimitConfiguration.up) * 1_000,
                isEnabled: speedLimitState.up
            )
        )

        isSaving = true
        errorMessage = nil

        Task {
            defer {
                isSaving = false
            }

            do {
                try await connection.setGlobalSpeedLimits(limits)
                await acquireData(showLoading: false)
            } catch {
                let message = error.localizedDescription
                await acquireData(showLoading: false)
                isErrored = true
                isLoading = false
                errorMessage = message
            }
        }
    }

    private static func displayedKilobytesPerSecond(from bytesPerSecond: Int64) -> Int? {
        guard bytesPerSecond >= 0 else {
            return nil
        }
        let kilobytes = bytesPerSecond / 1_000
            + (bytesPerSecond > 0 && bytesPerSecond % 1_000 != 0 ? 1 : 0)
        return Int(exactly: kilobytes)
    }
}
