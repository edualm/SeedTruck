//
//  ServerPickerToolbarItem.swift
//  SeedTruck (macOS)
//
//  AppKit bridge that puts a server picker in the sidebar section of the
//  window toolbar. On macOS 26, SwiftUI lays out every custom sidebar
//  `.toolbar` item on the detail side of the split view separator, so the
//  item is inserted directly into the `NSToolbar` instead.
//

import AppKit
import SwiftUI

/// Keeps the toolbar item narrow, which is what makes the sidebar minimum width predictable.
private let serverPickerMaximumDisplayNameLength = 20

func serverPickerDisplayName(for name: String) -> String {
    guard name.count > serverPickerMaximumDisplayNameLength else {
        return name
    }

    return String(name.prefix(serverPickerMaximumDisplayNameLength - 1)) + "…"
}

// MARK: - Model

@MainActor
final class ServerPickerModel: ObservableObject {

    @Published var servers: [Server] = []
    @Published var selectedServerID: UUID?
    var select: (Server) -> Void = { _ in }
}

// MARK: - View

/// Used when the toolbar item cannot be installed, as a header at the top of the sidebar.
struct ServerPickerView: View {

    @ObservedObject var model: ServerPickerModel

    var body: some View {
        if let selected = model.servers.first(where: { $0.id == model.selectedServerID }) {
            Menu {
                ForEach(model.servers, id: \.self) { server in
                    Toggle(
                        isOn: Binding(
                            get: { server.id == model.selectedServerID },
                            set: { isOn in
                                if isOn {
                                    model.select(server)
                                }
                            }
                        )
                    ) {
                        Text(server.name)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .accessibilityHidden(true)
                    Text(serverPickerDisplayName(for: selected.name))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 180, alignment: .leading)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Switch Server")
            .accessibilityLabel("Server")
            .accessibilityValue(selected.name)
            .accessibilityIdentifier("server-picker")
        } else {
            Text("No Server")
                .foregroundStyle(.secondary)
                .help("No server selected")
                .accessibilityLabel("Server")
                .accessibilityValue("No Server")
                .accessibilityIdentifier("server-picker")
        }
    }
}

// MARK: - Toolbar delegate proxy

@MainActor
final class ServerPickerToolbarProxy: NSObject, NSToolbarDelegate {

    static let itemIdentifier = NSToolbarItem.Identifier("io.edr.seedtruck.serverPicker")

    nonisolated(unsafe) private let original: any NSToolbarDelegate
    /// Called with `willBeInsertedIntoToolbar`: true for the live toolbar, false for e.g. the customization palette.
    private let makeItem: (Bool) -> NSToolbarItem
    private var isReinserting = false

    init(original: any NSToolbarDelegate, makeItem: @escaping (Bool) -> NSToolbarItem) {
        self.original = original
        self.makeItem = makeItem
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || original.responds(to: selector)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        original.responds(to: selector) ? original : super.forwardingTarget(for: selector)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == Self.itemIdentifier {
            return makeItem(flag)
        }

        return original.toolbar?(
            toolbar,
            itemForItemIdentifier: itemIdentifier,
            willBeInsertedIntoToolbar: flag
        )
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let existing = original.toolbarAllowedItemIdentifiers?(toolbar)
            ?? toolbar.items.map(\.itemIdentifier)

        return existing + [Self.itemIdentifier]
    }

    func toolbarDidRemoveItem(_ notification: Notification) {
        original.toolbarDidRemoveItem?(notification)

        guard
            let removed = notification.userInfo?["item"] as? NSToolbarItem,
            removed.itemIdentifier == Self.itemIdentifier,
            let toolbar = notification.object as? NSToolbar,
            !isReinserting
        else { return }

        // SwiftUI removes items it doesn't own whenever the toolbar's preferences change (the search text, the
        // detail's title, …), from inside a layout pass. Putting the item back right away, in that same pass,
        // means no frame is ever drawn without it; waiting for the next run loop turn made it flash.
        isReinserting = true
        insert(into: toolbar)
        isReinserting = false

        // Safety net, in case the same update removed it again or the separator wasn't there yet.
        RunLoop.main.perform {
            MainActor.assumeIsolated {
                _ = self.insert(into: toolbar)
            }
        }
    }

    @discardableResult
    func insert(into toolbar: NSToolbar) -> Bool {
        guard !toolbar.items.contains(where: { $0.itemIdentifier == Self.itemIdentifier }) else {
            return true
        }

        guard let separator = toolbar.items.firstIndex(where: {
            $0.itemIdentifier.rawValue.hasPrefix("com.apple.SwiftUI.splitViewSeparator")
                || $0 is NSTrackingSeparatorToolbarItem
        }) else {
            return false
        }

        toolbar.insertItem(withItemIdentifier: Self.itemIdentifier, at: separator)

        return true
    }
}

// MARK: - Controller

@MainActor
final class ServerPickerToolbarController: NSObject, ObservableObject {

    /// Whether the toolbar item couldn't be installed, so the picker should be shown in the sidebar instead.
    ///
    /// This is the only published state: `TorrentsView` owns this controller, so every publish re-renders it, and
    /// it's only ever assigned when it actually changes.
    @Published private(set) var didFail = false
    let model = ServerPickerModel()

    private weak var window: NSWindow?
    /// Kept for the window's lifetime and handed back on every re-insertion, so it isn't rebuilt each time.
    private var toolbarItem: NSMenuToolbarItem?
    private var proxy: ServerPickerToolbarProxy?
    private var attempts = 0
    private var isRetryScheduled = false
    nonisolated(unsafe) private var observers: [any NSObjectProtocol] = []

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func install(in window: NSWindow) {
        if self.window !== window {
            self.window = window
            toolbarItem = nil
            attempts = 0
            observe(window)
        }

        attemptInstall()
    }

    private func observe(_ window: NSWindow) {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }

        observers = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didEnterFullScreenNotification,
            NSWindow.didExitFullScreenNotification
        ].map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.attemptInstall()
                }
            }
        }
    }

    private func attemptInstall() {
        guard let window else { return }

        guard let toolbar = window.toolbar, let delegate = toolbar.delegate else {
            scheduleRetry()

            return
        }

        let proxy: ServerPickerToolbarProxy

        if let existing = delegate as? ServerPickerToolbarProxy {
            proxy = existing
        } else {
            proxy = ServerPickerToolbarProxy(original: delegate) { [weak self] willBeInserted in
                self?.toolbarItem(willBeInserted: willBeInserted)
                    ?? NSToolbarItem(itemIdentifier: ServerPickerToolbarProxy.itemIdentifier)
            }
            toolbar.delegate = proxy
        }

        self.proxy = proxy

        if proxy.insert(into: toolbar) {
            attempts = 0
            setDidFail(false)
        } else {
            scheduleRetry()
        }
    }

    private func setDidFail(_ value: Bool) {
        if didFail != value {
            didFail = value
        }
    }

    private func scheduleRetry() {
        guard !isRetryScheduled else { return }

        guard attempts < 30 else {
            setDidFail(true)

            return
        }

        attempts += 1
        isRetryScheduled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isRetryScheduled = false
            self?.attemptInstall()
        }
    }

    private func toolbarItem(willBeInserted: Bool) -> NSToolbarItem {
        // The customization palette needs its own instance; the toolbar always gets the same one back.
        if willBeInserted, let toolbarItem {
            return toolbarItem
        }

        let item = makeToolbarItem()

        if willBeInserted {
            toolbarItem = item
        }

        return item
    }

    private func makeToolbarItem() -> NSMenuToolbarItem {
        let item = NSMenuToolbarItem(itemIdentifier: ServerPickerToolbarProxy.itemIdentifier)

        item.label = "Server"
        item.paletteLabel = "Server"
        item.toolTip = "Switch Server"
        item.isBordered = true
        item.showsIndicator = true

        configure(item)

        return item
    }

    private func updateToolbarItem() {
        if let toolbarItem {
            configure(toolbarItem)
        }
    }

    private func configure(_ item: NSMenuToolbarItem) {
        let selected = model.servers.first { $0.id == model.selectedServerID }

        item.isEnabled = !model.servers.isEmpty
        item.title = selected.map { serverPickerDisplayName(for: $0.name) } ?? "No Server"
        item.image = selected == nil
            ? nil
            : NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)

        let menu = NSMenu()
        menu.autoenablesItems = false

        for server in model.servers {
            let menuItem = NSMenuItem(
                title: server.name,
                action: #selector(selectServer(_:)),
                keyEquivalent: ""
            )

            menuItem.target = self
            menuItem.representedObject = server.id
            menuItem.state = server.id == model.selectedServerID ? .on : .off
            menu.addItem(menuItem)
        }

        if model.servers.isEmpty {
            let emptyItem = NSMenuItem(title: "No Servers", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        item.menu = menu
    }

    @objc private func selectServer(_ sender: NSMenuItem) {
        guard
            let id = sender.representedObject as? UUID,
            let server = model.servers.first(where: { $0.id == id })
        else { return }

        model.select(server)
    }

    func update(servers: [Server], selectedID: UUID?, select: @escaping (Server) -> Void) {
        // Only publish real changes: re-publishing every time invalidates the picker for no reason.
        let serversChanged = model.servers != servers
        let selectionChanged = model.selectedServerID != selectedID

        if serversChanged {
            model.servers = servers
        }
        if selectionChanged {
            model.selectedServerID = selectedID
        }

        model.select = select

        if serversChanged || selectionChanged {
            updateToolbarItem()
        }
    }
}

// MARK: - Window accessor

/// Reports the window the view is in, once per window change. It must not report from `updateNSView`: that runs
/// on every render of the hosting view, and reacting to it re-rendered the view in a loop.
struct WindowAccessor: NSViewRepresentable {

    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowReportingView {
        let view = WindowReportingView()
        view.onWindow = onWindow

        return view
    }

    func updateNSView(_ view: WindowReportingView, context: Context) {
        view.onWindow = onWindow
    }

    final class WindowReportingView: NSView {

        var onWindow: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            guard let window else { return }

            // Deferred so SwiftUI has finished attaching its toolbar to the window.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window === window else { return }

                self.onWindow?(window)
            }
        }
    }
}
