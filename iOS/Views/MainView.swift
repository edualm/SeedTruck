//
//  MainView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @EnvironmentObject private var serverRepository: ServerRepository
    
    private var tabContent: some View {
        Group {
            TorrentsView()
                .tabItem {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Torrents")
                }
            SettingsView(presenter: SettingsPresenter(repository: serverRepository))
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Settings")
                }
        }
        .toolbar(.visible, for: .tabBar)
    }
    
    var body: some View {
        TabView { tabContent }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView().environmentObject(PreviewMockData.serverRepository)
    }
}
