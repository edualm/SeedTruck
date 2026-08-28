//
//  RemoteServerSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 04/10/2021.
//

import SwiftUI

struct RemoteServerSettingsSheet: View {

    @StateObject private var presenter: RemoteServerSettingsPresenter

    init(server: Server) {
        self._presenter = StateObject(
            wrappedValue: RemoteServerSettingsPresenter(server: server)
        )
    }

    var body: some View {
        NavigationStack {
            RemoteServerSettingsView(presenter: presenter)
        }
        .frame(width: 520, height: 425)
        .interactiveDismissDisabled(presenter.isSaving)
        .accessibilityIdentifier("speed-limits-sheet")
    }
}

struct RemoteServerSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var presenter: RemoteServerSettingsPresenter

    private var settings: some View {
        Form {
            Section {
                LabeledContent {
                    HStack(spacing: 6) {
                        TextField(
                            "Download speed limit",
                            value: $presenter.speedLimitConfiguration.down,
                            format: .number
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        Text("kB/s")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                }

                LabeledContent {
                    HStack(spacing: 6) {
                        TextField(
                            "Upload speed limit",
                            value: $presenter.speedLimitConfiguration.up,
                            format: .number
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        Text("kB/s")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle.fill")
                }
            } header: {
                Text("Rates")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Values use kB/s (1 kB = 1,000 bytes).")
                    if !presenter.hasValidSpeedLimits {
                        Text("Enabled speed limits must be greater than zero.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(presenter.isSaving)

            Section("Active Limits") {
                Toggle("Download", isOn: $presenter.speedLimitState.down)
                    .toggleStyle(.switch)
                    .disabled(presenter.isSaving)

                Toggle("Upload", isOn: $presenter.speedLimitState.up)
                    .toggleStyle(.switch)
                    .disabled(presenter.isSaving)
            }
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .contentMargins(.vertical, 16, for: .scrollContent)
    }

    @ViewBuilder
    private var innerView: some View {
        if presenter.isLoading {
            ProgressView("Loading speed limits...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !presenter.hasServerSupport {
            ContentUnavailableView(
                "Speed Limits Unavailable",
                systemImage: "gauge.with.dots.needle.67percent",
                description: Text("This server does not support remote speed-limit settings.")
            )
            .padding(32)
        } else if presenter.isErrored {
            ContentUnavailableView {
                Label("Unable to Load Speed Limits", systemImage: "wifi.exclamationmark")
            } description: {
                Text(presenter.errorMessage ?? "The server settings could not be loaded.")
            } actions: {
                Button("Retry", action: presenter.retry)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(32)
        } else {
            settings
        }
    }

    private var showsApplyAction: Bool {
        !presenter.isLoading && presenter.hasServerSupport && !presenter.isErrored
    }

    private var applyButton: some View {
        Button(action: presenter.applyChanges) {
            HStack(spacing: 8) {
                if presenter.isSaving {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("Apply")
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!presenter.canApplyChanges)
        .accessibilityIdentifier("speed-limits-apply")
    }

    var body: some View {
        VStack(spacing: 0) {
            innerView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(presenter.isSaving)

                if showsApplyAction {
                    applyButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.background)
        .navigationTitle("Speed Limits")
    }
}

struct RemoteServerSettingsView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            if let server = PreviewMockData.settingsServer {
                NavigationStack {
                    RemoteServerSettingsView(
                        presenter: RemoteServerSettingsPresenter(
                            server: server,
                            connection: PreviewServerConnection()
                        )
                    )
                }
                .frame(width: 520, height: 425)
            } else {
                ContentUnavailableView("Preview Unavailable", systemImage: "server.rack")
            }
        }
    }
}
