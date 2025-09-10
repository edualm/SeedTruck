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
    
    private var tabContent: some View {
        Group {
            TorrentsView()
                .tabItem {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Torrents")
                }
            SettingsView(presenter: SettingsPresenter(managedObjectContext: managedObjectContext))
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Settings")
                }
        }
        .toolbar(.visible, for: .tabBar)
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView { tabContent }
                .tabViewBottomAccessory {
                    FloatingServerStatusView(torrents: sharedBucket.torrents)
                }
        } else {
            TabView { tabContent }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView().environmentObject(SharedBucket())
    }
}
