//
//  RemoteServerSettingsView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 04/10/2021.
//

import SwiftUI

struct RemoteServerSettingsView: View {

    @ObservedObject var presenter: RemoteServerSettingsPresenter
    
    @ViewBuilder
    var innerView: some View {
        VStack {
            if presenter.isLoading {
                LoadingView()
            } else {
                if !presenter.hasServerSupport {
                    Text("No server support.")
                } else if presenter.isErrored {
                    VStack(spacing: 12) {
                        ErrorView(type: .noConnection)
                        Text(presenter.errorMessage ?? "Unable to load server settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry", action: presenter.retry)
                    }
                } else {
                    Form {
                        Section {
                            HStack {
                                Label("Download", systemImage: "arrow.down.circle.fill")
                                Spacer()
                                TextField(
                                    "0",
                                    value: $presenter.speedLimitConfiguration.down,
                                    format: .number
                                )
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .accessibilityLabel("Download speed limit")
                                Text("kB/s")
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                Label("Upload", systemImage: "arrow.up.circle.fill")
                                Spacer()
                                TextField(
                                    "0",
                                    value: $presenter.speedLimitConfiguration.up,
                                    format: .number
                                )
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                                .accessibilityLabel("Upload speed limit")
                                Text("kB/s")
                                    .foregroundStyle(.secondary)
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
                        
                        Section(header: Text("Active Limits")) {
                            Toggle("Download Speed Limit", isOn: $presenter.speedLimitState.down)
                            Toggle("Upload Speed Limit", isOn: $presenter.speedLimitState.up)
                        }
                        .disabled(presenter.isSaving)
                    }
                }
            }
        }
    }
    
    var body: some View {
        innerView
            .navigationTitle("Speed Limits")
            .toolbar {
                if !presenter.isLoading,
                   presenter.hasServerSupport,
                   !presenter.isErrored {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: presenter.applyChanges) {
                            if presenter.isSaving {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark")
                            }
                        }
                        .disabled(!presenter.canApplyChanges)
                        .accessibilityLabel("Apply Speed Limits")
                        .accessibilityIdentifier("speed-limits-apply")
                    }
                }
            }
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
            } else {
                ContentUnavailableView("Preview Unavailable", systemImage: "server.rack")
            }
        }
    }
}
