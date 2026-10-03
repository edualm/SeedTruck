//
//  GeneralSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    @AppStorage(Constants.StorageKeys.appIcon) private var appIcon = AppIconOption.default
    @AppStorage(Constants.StorageKeys.autoUpdateInterval) private var autoUpdateInterval = 2

    private var refreshInterval: Binding<RefreshIntervalOption> {
        Binding(
            get: { RefreshIntervalOption(storedValue: autoUpdateInterval) },
            set: { autoUpdateInterval = $0.rawValue }
        )
    }

    private func appIconButton(_ option: AppIconOption) -> some View {
        Button {
            appIcon = option
        } label: {
            VStack(spacing: 4) {
                Image(nsImage: option.image ?? NSImage())
                    .resizable()
                    .frame(width: 64, height: 64)
                    .padding(4)
                    .background {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(.tint, lineWidth: 2)
                            .opacity(option == appIcon ? 1 : 0)
                    }
                    .accessibilityHidden(true)

                Text(option.title)
                    .font(.caption)
                    .foregroundStyle(option == appIcon ? .primary : .secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(option == appIcon ? .isSelected : [])
        .accessibilityIdentifier("settings-app-icon-\(option.rawValue)")
    }

    var body: some View {
        Form {
            Section {
                Picker("Refresh interval", selection: refreshInterval) {
                    ForEach(RefreshIntervalOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .accessibilityIdentifier("settings-refresh-interval")
            } header: {
                Text("Updates")
            } footer: {
                Text("Controls how often torrent lists and details update. Choose Manual only to refresh on demand.")
            }

            Section {
                HStack(spacing: 16) {
                    ForEach(AppIconOption.allCases) { option in
                        appIconButton(option)
                    }
                }
                .frame(maxWidth: .infinity)
            } header: {
                Text("App Icon")
            } footer: {
                Text("The icon only changes in the Dock while Seed Truck is open. When it’s closed, Finder and the Dock show the default icon.")
            }
        }
        .onChange(of: appIcon) { _, newValue in
            newValue.applyToDock()
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .contentMargins(.vertical, 16, for: .scrollContent)
        .accessibilityIdentifier("settings-general-pane")
    }
}

struct GeneralSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        GeneralSettingsView()
            .frame(width: 500, height: 380)
    }
}
