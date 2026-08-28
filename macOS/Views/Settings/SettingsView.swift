//
//  SettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct SettingsView: View {

    private enum Tab: Hashable {
        case general
        case servers
    }

    @EnvironmentObject private var serverRepository: ServerRepository
    @State private var selectedTab = Tab.general

    private var contentSize: CGSize {
        switch selectedTab {
        case .general:
            return CGSize(width: 500, height: 220)
        case .servers:
            return CGSize(width: 540, height: 320)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tab.general)

            ServerSettingsView(repository: serverRepository)
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
                .tag(Tab.servers)
        }
        .frame(width: contentSize.width, height: contentSize.height)
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        SettingsView()
            .environmentObject(PreviewMockData.serverRepository)
    }
}
