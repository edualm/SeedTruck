//
//  MainView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    @EnvironmentObject private var sharedBucket: SharedBucket
    
    @State private var selectedTab = 0
    
    private var tabContent: some View {
        Group {
            TorrentsView()
                .tabItem {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Torrents")
                }
                .tag(0)
            SettingsView(presenter: SettingsPresenter(managedObjectContext: managedObjectContext))
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Settings")
                }
                .tag(1)
        }
        .toolbar(.visible, for: .tabBar)
    }
    
    var body: some View {
        if #available(iOS 26.1, *) {
            TabView(selection: $selectedTab) { tabContent }
                .tabViewBottomAccessory(isEnabled: selectedTab == 0) {
                    FloatingServerStatusView(torrents: sharedBucket.torrents)
                }
        } else {
            TabView(selection: $selectedTab) { tabContent }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView().environmentObject(SharedBucket())
    }
}
