//
//  ServerSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct ServerSettingsView: View {

    private struct EditorPresentation: Identifiable {
        let id = UUID()
        let server: Server?
    }

    private struct SpeedLimitsPresentation: Identifiable {
        let id = UUID()
        let server: Server
    }

    @ObservedObject private var repository: ServerRepository

    @StateObject private var presenter: SettingsPresenter
    @State private var selectedServerID: UUID?
    @State private var editorPresentation: EditorPresentation?
    @State private var speedLimitsPresentation: SpeedLimitsPresentation?

    private var serverConnections: [Server] { repository.servers }

    private var selectedServer: Server? {
        serverConnections.first { $0.id == selectedServerID }
    }

    private var selectedServerSupportsSpeedLimits: Bool {
        selectedServer?.connection is GlobalSpeedLimitSupporting
    }

    init(repository: ServerRepository) {
        self._repository = ObservedObject(wrappedValue: repository)
        self._presenter = StateObject(
            wrappedValue: SettingsPresenter(repository: repository)
        )
    }

    private func edit(_ server: Server) {
        selectedServerID = server.id
        editorPresentation = EditorPresentation(server: server)
    }

    private func requestDeletion(of server: Server) {
        selectedServerID = server.id
        presenter.perform(.delete(server))
    }

    private func server(in selection: Set<UUID>) -> Server? {
        guard selection.count == 1, let id = selection.first else {
            return nil
        }

        return serverConnections.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                List(selection: $selectedServerID) {
                    ForEach(serverConnections) { server in
                        HStack(spacing: 10) {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.tint)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(server.name)
                                    .lineLimit(1)
                                Text(server.displayHost)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .tag(server.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings-server-row-\(server.name)")
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .accessibilityIdentifier("settings-server-list")
                .contextMenu(forSelectionType: UUID.self) { selection in
                    if let server = server(in: selection) {
                        Button("Edit Server...") {
                            edit(server)
                        }
                        Button("Delete Server", role: .destructive) {
                            requestDeletion(of: server)
                        }
                    }
                } primaryAction: { selection in
                    if let server = server(in: selection) {
                        edit(server)
                    }
                }
                .onDeleteCommand {
                    if let selectedServer {
                        requestDeletion(of: selectedServer)
                    }
                }

                if serverConnections.isEmpty {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text("Add a torrent client to get started.")
                    )
                    .allowsHitTesting(false)
                }
            }

            Divider()

            HStack(spacing: 2) {
                Button {
                    editorPresentation = EditorPresentation(server: nil)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(Text(verbatim: "Add Server"))
                .accessibilityLabel("Add Server")
                .accessibilityIdentifier("settings-add-server")

                Button {
                    if let selectedServer {
                        requestDeletion(of: selectedServer)
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(selectedServer == nil)
                .help(Text(verbatim: "Delete Selected Server"))
                .accessibilityLabel("Delete Selected Server")
                .accessibilityIdentifier("settings-delete-server")

                Button {
                    repository.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 28, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(Text(verbatim: "Refresh Servers"))
                .accessibilityLabel("Refresh Servers")
                .accessibilityIdentifier("settings-refresh-servers")

                Spacer()

                Button("Speed Limits...") {
                    if let selectedServer {
                        speedLimitsPresentation = SpeedLimitsPresentation(server: selectedServer)
                    }
                }
                .disabled(!selectedServerSupportsSpeedLimits)
                .accessibilityIdentifier("settings-speed-limits")

                Button("Edit...") {
                    if let selectedServer {
                        edit(selectedServer)
                    }
                }
                .disabled(selectedServer == nil)
                .accessibilityIdentifier("settings-edit-server")
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary)
        }
        .scenePadding()
        .sheet(item: $editorPresentation) { presentation in
            ServerEditorSheet(
                server: presentation.server,
                repository: repository
            )
        }
        .sheet(item: $speedLimitsPresentation) { presentation in
            RemoteServerSettingsSheet(server: presentation.server)
        }
        .alert("Delete Server?", isPresented: $presenter.showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                presenter.perform(.confirmDeletion)
                selectedServerID = nil
            }
            Button("Cancel", role: .cancel) {
                presenter.perform(.abortDeletion)
            }
        } message: {
            if let server = presenter.serverUnderModification {
                Text("This removes \"\(server.name)\" and its saved credentials.")
            }
        }
        .alert(
            presenter.persistenceErrorIsCleanupWarning
                ? "Server Deleted with Cleanup Warning"
                : "Unable to Delete Server",
            isPresented: Binding(
                get: { presenter.persistenceError != nil },
                set: { if !$0 { presenter.persistenceError = nil } }
            )
        ) {
            Button("OK") {
                presenter.persistenceError = nil
            }
        } message: {
            Text(presenter.persistenceError ?? "The server could not be deleted.")
        }
    }
}

struct ServerSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerSettingsView(
            repository: PreviewMockData.serverRepository
        )
    }
}
