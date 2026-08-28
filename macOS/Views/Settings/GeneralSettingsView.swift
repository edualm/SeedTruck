//
//  GeneralSettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct GeneralSettingsView: View {
    
    @AppStorage(Constants.StorageKeys.autoUpdateInterval) private var autoUpdateInterval = 2

    private var refreshInterval: Binding<RefreshIntervalOption> {
        Binding(
            get: { RefreshIntervalOption(storedValue: autoUpdateInterval) },
            set: { autoUpdateInterval = $0.rawValue }
        )
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
            .frame(width: 500, height: 220)
    }
}
