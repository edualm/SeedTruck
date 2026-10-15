//
//  MainView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct MainView: View {
    
    private enum Tab: Hashable {
        case torrents
        case settings
    }
    
    @EnvironmentObject private var serverRepository: ServerRepository
    
    @State private var selectedTab = Tab.torrents
    
    private var tabContent: some View {
        Group {
            TorrentsView()
                .tabItem {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Torrents")
                }
                .tag(Tab.torrents)
            SettingsView(presenter: SettingsPresenter(repository: serverRepository))
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .toolbar(.visible, for: .tabBar)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) { tabContent }
        #if DEBUG
            .task {
                if Showcase.scene == .limits {
                    selectedTab = .settings
                }
            }
        #endif
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView().environmentObject(PreviewMockData.serverRepository)
    }
}
