//
//  SettingsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SafariServices
import SwiftUI

private struct InAppBrowserDestination: Identifiable {

    let url: URL

    var id: URL { url }
}

private struct InAppBrowserView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.view.accessibilityIdentifier = "settings-in-app-browser"
        return controller
    }

    func updateUIViewController(
        _ uiViewController: SFSafariViewController,
        context: Context
    ) {}
}

struct SettingsView: View {

    private struct AlertData: Identifiable {
        var id: String { title + message }
        let title: String
        let message: String
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var serverRepository: ServerRepository

    @AppStorage(Constants.StorageKeys.autoUpdateInterval) private var autoUpdateInterval = 2

    @State private var alertData: AlertData?
    @State private var appIcon = AppIconOption.default
    @State private var inAppBrowserDestination: InAppBrowserDestination?
    @State private var selectedArea: SettingsArea? = .general

    @ObservedObject private var presenter: SettingsPresenter

    private var refreshInterval: Binding<RefreshIntervalOption> {
        Binding(
            get: { RefreshIntervalOption(storedValue: autoUpdateInterval) },
            set: { autoUpdateInterval = $0.rawValue }
        )
    }

    init(presenter: SettingsPresenter) {
        self.presenter = presenter
    }

    private var serverConnections: [Server] { serverRepository.servers }

    private func serverRow(_ server: Server) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(server.name)
                    .font(.headline)
                Text(server.displayHost)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    TorrentClientRegistry.live
                        .descriptor(for: ServerType(rawValue: server.type))?
                        .displayName
                        ?? "Unsupported client (\(server.type))"
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func appIconRow(_ option: AppIconOption) -> some View {
        Button {
            selectAppIcon(option)
        } label: {
            HStack(spacing: 12) {
                Image(option.previewImageName)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                Text(option.title)
                    .foregroundStyle(Color.primary)

                Spacer()

                if option == appIcon {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(option == appIcon ? .isSelected : [])
        .accessibilityIdentifier("settings-app-icon-\(option.rawValue)")
    }

    private func selectAppIcon(_ option: AppIconOption) {
        guard option != appIcon else { return }

        let previousIcon = appIcon
        appIcon = option

        Task {
            do {
                // This only returns once the system confirmation alert is dismissed.
                try await UIApplication.shared.setAlternateIconName(option.alternateIconName)
            } catch {
                appIcon = previousIcon
                alertData = .init(
                    title: "Unable to Change App Icon",
                    message: error.localizedDescription
                )
            }
        }
    }

    private var generalContent: some View {
        Form {
            Section {
                Picker("Refresh interval", selection: refreshInterval) {
                    ForEach(RefreshIntervalOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
#if os(iOS)
                .pickerStyle(.menu)
#endif
                .accessibilityIdentifier("settings-refresh-interval")
            } header: {
                Text("Updates")
            } footer: {
                Text("Controls how often torrent lists and details update. Choose Manual only to refresh on demand.")
            }

            if UIApplication.shared.supportsAlternateIcons {
                Section {
                    ForEach(AppIconOption.allCases) { option in
                        appIconRow(option)
                    }
                } header: {
                    Text("App Icon")
                }
            }
        }
        .onAppear {
            appIcon = AppIconOption(alternateIconName: UIApplication.shared.alternateIconName)
        }
        .navigationTitle("General")
#if os(iOS)
        .formStyle(.grouped)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var serversContent: some View {
        List {
            if serverConnections.isEmpty {
                ContentUnavailableView(
                    "No Servers",
                    systemImage: "server.rack",
                    description: Text("Add a torrent client to begin.")
                )
#if os(iOS)
                .offset(y: 8)
#endif
            } else {
                ForEach(serverConnections) { server in
                    let serverID = server.id
                    let serverName = server.name

                    NavigationLink {
                        ServerDetailsView(serverID: serverID, serverName: serverName)
                    } label: {
                        serverRow(server)
                    }
#if os(iOS)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            presenter.perform(.delete(server))
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .accessibilityLabel("Delete \(server.name)")
                        }
                    }
#elseif os(tvOS)
                    .contextMenu {
                        Button(role: .destructive) {
                            presenter.perform(.delete(server))
                        } label: {
                            Label("Delete \(server.name)", systemImage: "trash")
                        }
                    }
#endif
                }
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Servers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    serverRepository.refresh()
                } label: {
                    Label("Refresh Servers", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("settings-refresh-servers")

                NavigationLink {
                    NewServerView()
                } label: {
                    Label("Add Server", systemImage: "plus")
                }
                .accessibilityIdentifier("settings-add-server")
            }
        }
    }

    private func supportLink(
        _ title: String,
        systemImage: String,
        destination: URL,
        identifier: String
    ) -> some View {
        Link(destination: destination) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .accessibilityIdentifier(identifier)
    }

    private var helpContent: some View {
        Form {
            Section {
                supportLink(
                    "Help Center",
                    systemImage: "questionmark.circle",
                    destination: SeedTruckSupportLinks.helpCenterURL,
                    identifier: "settings-help-center"
                )
                supportLink(
                    "Submit a Support Request",
                    systemImage: "envelope",
                    destination: SeedTruckSupportLinks.supportTicketURL(
                        platformIdentifier: SeedTruckSupportLinks.currentPlatformIdentifier
                    ),
                    identifier: "settings-submit-support-request"
                )
                supportLink(
                    "Privacy Policy",
                    systemImage: "hand.raised",
                    destination: SeedTruckSupportLinks.privacyPolicyURL,
                    identifier: "settings-privacy-policy"
                )
            }
        }
        .formStyle(.grouped)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings-help-page")
        .environment(\.openURL, OpenURLAction { url in
            inAppBrowserDestination = InAppBrowserDestination(url: url)
            return .handled
        })
        .sheet(item: $inAppBrowserDestination) { destination in
            InAppBrowserView(url: destination.url)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func content(for area: SettingsArea) -> some View {
        switch area {
        case .general:
            generalContent
        case .servers:
            serversContent
        case .help:
            helpContent
        }
    }

    private var areaList: some View {
        List(SettingsArea.allCases) { area in
            NavigationLink {
                content(for: area)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(area.title)
                        Text(area.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: area.systemImage)
                }
            }
            .accessibilityIdentifier("settings-area-\(area.rawValue)")
        }
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var navigationContent: some View {
        #if os(iOS)
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(SettingsArea.allCases, selection: $selectedArea) { area in
                    Label(area.title, systemImage: area.systemImage)
                        .tag(area)
                        .accessibilityIdentifier("settings-area-\(area.rawValue)")
                }
                .navigationTitle("Settings")
            } detail: {
                content(for: selectedArea ?? .general)
            }
        } else {
            NavigationStack {
                areaList
            }
        }
        #else
        NavigationStack {
            areaList
        }
        #endif
    }

    var body: some View {
        navigationContent
            .onChange(of: presenter.persistenceError) { _, error in
                guard let error else { return }
                alertData = .init(
                    title: presenter.persistenceErrorIsCleanupWarning
                        ? "Server Deleted with Cleanup Warning"
                        : "Unable to Delete Server",
                    message: error
                )
                presenter.persistenceError = nil
            }
            .alert(
                "Delete Server?",
                isPresented: $presenter.showingDeleteAlert,
                presenting: presenter.serverUnderModification
            ) { server in
                Button("Delete", role: .destructive) {
                    presenter.perform(.confirmDeletion)
                }
                Button("Cancel", role: .cancel) {
                    presenter.perform(.abortDeletion)
                }
            } message: { server in
                Text("Are you sure you want to delete \"\(server.name)\"?")
            }
            .alert(item: $alertData) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

struct SettingsView_Previews: PreviewProvider {

    static var previews: some View {
        SettingsPreview()
            .previewDisplayName("Seeded Settings")
    }
}

@MainActor
private struct SettingsPreview: View {

    @StateObject private var serverRepository = PreviewMockData.serverRepository

    var body: some View {
        SettingsView(
            presenter: SettingsPresenter(
                repository: serverRepository
            )
        )
        .environmentObject(serverRepository)
    }
}
