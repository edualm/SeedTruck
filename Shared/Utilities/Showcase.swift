//
//  Showcase.swift
//  SeedTruck
//

#if DEBUG
import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Stages App Store screenshots and previews (DEBUG only). `--showcase <scene>` opens one prepared moment with the
/// sample seedbox from `SHOWCASE_STATE`: a server called My Server, served by an in-memory connection instead of
/// the network, and kept out of the Keychain. `scripts/store/capture.sh` launches each scene and captures it once
/// the log says it's done.
///
/// | Argument or variable | Effect |
/// | --- | --- |
/// | `--showcase <scene>` | One of `Scene`'s raw values |
/// | `--showcase-log <file>` | Writes JSON lines `{t, wall, event}`; a relative path is in the app's Caches |
/// | `--showcase-window 850x600` | Mac: opens the main window at that content size |
/// | `--showcase-landscape` | iPad: turns to landscape (the capture build sets `UIRequiresFullScreen`) |
/// | `--showcase-appearance dark` | Mac: light or dark (simulators are switched by the scripts instead) |
/// | `SHOWCASE_STATE` | Base64 of the fixture's `state` JSON: the server, its torrents, labels, and limits |
/// | `SHOWCASE_SESSION` | A fresh UUID per launch |
///
/// Each scene is reached the way a person would get there: the view that owns the state (the selected torrent,
/// the presented sheet, the settings page) sets it from its own `.task` once the list has loaded, then logs `done`.
enum Showcase {

    enum Scene: String {
        /// The torrent list.
        case list
        /// The fixture's selected torrent, in its details.
        case details
        /// The Add Torrent sheet for the fixture's torrent file, as when opening one from Files or the Finder.
        case add
        /// The server's global speed limits.
        case limits
    }

    private static let arguments = ProcessInfo.processInfo.arguments

    static let scene = value("--showcase").flatMap(Scene.init(rawValue:))
    static let landscape = arguments.contains("--showcase-landscape")
    static var isActive: Bool { scene != nil }

    /// The fixture's state, decoded from `SHOWCASE_STATE`.
    static var stateData: Data? {
        ProcessInfo.processInfo.environment["SHOWCASE_STATE"]
            .flatMap { Data(base64Encoded: $0) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Set on every scripted launch: a fresh ID to name isolated storage after.
    static let session = ProcessInfo.processInfo.environment["SHOWCASE_SESSION"]

    /// The value after a flag. The scripts put a shot's own arguments first, so the first occurrence wins.
    static func value(_ flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Polls until `condition` holds or `timeout` passes; false on timeout.
    @MainActor @discardableResult
    static func until(timeout: Double = 30, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while !condition() {
            guard ContinuousClock.now < deadline, !Task.isCancelled else { return false }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return true
    }

    static func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: Sample seedbox

    /// The fixture's state. Torrents are in Transmission's `torrent_get` format, like `Tools/mockserver`'s, and go
    /// through the app's own Transmission parsing. Keys are snake case.
    struct State: Decodable {

        struct SpeedLimits: Decodable {

            /// kB/s, as Transmission's session settings.
            let download: Int64
            let upload: Int64
            let downloadEnabled: Bool
            let uploadEnabled: Bool
        }

        struct TorrentFile: Decodable {

            let name: String
            let size: Int64
            let labels: [String]
        }

        let server: String
        let endpoint: URL
        let torrents: [Transmission.Torrent]
        let labels: [String]
        let speedLimits: SpeedLimits
        let torrentFile: TorrentFile
        let selectedTorrent: String
    }

    static let state: State? = {
        guard isActive, let stateData else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(State.self, from: stateData)
        } catch {
            log("failed: state: \(error)")
            return nil
        }
    }()

    /// The fixture's server, with a fixed ID.
    static let server: Server? = state.map {
        Server(
            id: UUID(uuidString: "5EED7A0C-0000-4000-8000-000000000001")!,
            endpoint: $0.endpoint,
            name: $0.server,
            type: ServerType.transmission.rawValue
        )
    }

    /// Stands in for the Keychain while showcasing, so the developer's servers are neither shown nor changed.
    @MainActor
    static var serverStore: (any ServerStoring)? {
        server.map { ShowcaseServerStore(servers: [$0]) }
    }

    /// Stands in for the network while showcasing.
    static var connectionBuilder: (any ServerConnectionBuilding)? {
        state.map(ShowcaseConnectionBuilder.init(state:))
    }

    #if os(iOS) || os(macOS)
    /// The fixture's torrent file, as `LocalTorrent(validating:)` would read it.
    static var torrentFile: LocalTorrent? {
        state.map { state in
            let file = state.torrentFile
            return .torrent(
                data: Data(),
                metadata: .init(
                    name: file.name,
                    isPrivate: false,
                    files: [.init(path: file.name, size: file.size)],
                    totalSize: file.size
                ),
                labels: file.labels
            )
        }
    }
    #endif

    // MARK: Log

    private static let logURL: URL? = value("--showcase-log").map { path in
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(path)
    }
    nonisolated(unsafe) private static var logStarted = false
    private static let logLock = NSLock()

    /// Appends `{t, wall, event}`: seconds of system uptime, Unix seconds, and the event. The first entry replaces
    /// any earlier log at the path. Log `failed: <reason>` to stop the scripts with that reason.
    static func log(_ event: String) {
        guard let logURL else { return }
        logLock.lock()
        defer { logLock.unlock() }
        let entry: [String: Any] = ["t": ProcessInfo.processInfo.systemUptime,
                                    "wall": Date().timeIntervalSince1970, "event": event]
        guard var line = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        line.append(0x0a)
        if !logStarted {
            logStarted = true
            try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? line.write(to: logURL)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line)
    }

    // MARK: Staging

    /// Whether `start()` has finished: the window is sized or turned, so scenes can be staged.
    @MainActor private(set) static var isStarted = false
    @MainActor private static var isFinished = false

    /// Prepares the window, once: call from the root view's `.task`. Scenes wait for it before staging.
    @MainActor
    static func start() async {
        guard let scene, !isStarted else { return }
        guard state != nil else {
            log("failed: no fixture state for \(scene.rawValue)")
            return
        }
        #if os(macOS)
        await sizeWindow()
        #endif
        log("launched")
        #if os(iOS)
        if landscape { await turnToLandscape() }
        #endif
        isStarted = true
    }

    /// Waits for `start()`, then for `condition` (such as the list having loaded). False on timeout, after logging
    /// the failure.
    @MainActor
    static func stage(_ scene: Scene, when condition: () -> Bool = { true }) async -> Bool {
        guard self.scene == scene, !isFinished else { return false }
        guard await until({ isStarted && condition() }) else {
            log("failed: \(scene.rawValue) never became ready")
            return false
        }
        return true
    }

    /// Logs `ready` and `done` once pushes and sheets have finished animating, once per launch.
    @MainActor
    static func finish(after seconds: Double = 1.5) async {
        guard !isFinished else { return }
        isFinished = true
        await pause(seconds)
        log("ready")
        log("done")
    }

    // MARK: Platform

    #if os(iOS)
    /// Turns an iPad, or an open iPhone Duo, to landscape and returns once the turn has finished, so the brief
    /// inactivity while it turns is over before anything is staged.
    @MainActor
    static func turnToLandscape() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
            log("failed: landscape: \(error.localizedDescription)")
        }
        await until(timeout: 10) { scene.effectiveGeometry.interfaceOrientation.isLandscape }
        await until(timeout: 10) { scene.activationState == .foregroundActive }
        await pause(0.5)
    }
    #endif

    #if os(macOS)
    /// Applies `--showcase-appearance light|dark` to the whole app.
    @MainActor
    static func applyAppearance() {
        switch value("--showcase-appearance") {
        case "dark": NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
        default: break
        }
    }

    /// Sizes the main window's content to `--showcase-window`, centred. Call once the window is on screen.
    @MainActor
    static func sizeWindow() async {
        guard let size = value("--showcase-window") else { return }
        let parts = size.split(separator: "x").compactMap { Double($0) }
        guard parts.count == 2 else { return }
        await until(timeout: 10) { NSApplication.shared.windows.contains(where: \.isVisible) }
        guard let window = NSApplication.shared.windows.first(where: \.isVisible) else { return }
        window.setContentSize(NSSize(width: parts[0], height: parts[1]))
        window.center()
    }
    #endif
}

@MainActor
private final class ShowcaseServerStore: ServerStoring {

    private var stored: [Server]

    init(servers: [Server]) {
        stored = servers
    }

    func servers() throws -> [Server] {
        stored
    }

    func set(_ server: Server) throws {
        stored.removeAll { $0.id == server.id }
        stored.append(server)
    }

    func removeServer(id: UUID) throws {
        stored.removeAll { $0.id == id }
    }
}

private struct ShowcaseConnectionBuilder: ServerConnectionBuilding {

    let state: Showcase.State

    func makeConnection(for details: ConnectionDetails) -> any ServerConnection {
        ShowcaseConnection(
            torrents: state.torrents.compactMap(RemoteTorrent.init(from:)),
            labels: state.labels,
            limits: .init(
                download: .init(
                    bytesPerSecond: state.speedLimits.download * 1_000,
                    isEnabled: state.speedLimits.downloadEnabled
                ),
                upload: .init(
                    bytesPerSecond: state.speedLimits.upload * 1_000,
                    isEnabled: state.speedLimits.uploadEnabled
                )
            )
        )
    }
}

/// The fixture's seedbox: answers like a Transmission server would, and changes nothing.
private struct ShowcaseConnection: ServerConnection, GlobalSpeedLimitSupporting, TorrentTagProviding {

    let torrents: [RemoteTorrent]
    let labels: [String]
    let limits: GlobalSpeedLimits

    func checkConnection() async throws {}

    #if os(iOS) || os(macOS)
    func addTorrent(_ request: TorrentAddRequest) async throws {}
    #endif

    func getTorrent(id: String) async throws -> RemoteTorrent {
        guard let torrent = torrents.first(where: { $0.id == id }) else {
            throw ServerCommunicationError.invalidResponse
        }
        return torrent
    }

    func getTorrents() async throws -> [RemoteTorrent] {
        torrents
    }

    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent) async throws {}

    func globalSpeedLimits() async throws -> GlobalSpeedLimits {
        limits
    }

    func setGlobalSpeedLimits(_ limits: GlobalSpeedLimits) async throws {}

    func availableTags() async throws -> [String] {
        labels
    }
}
#endif
