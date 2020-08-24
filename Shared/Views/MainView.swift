//
//  MainView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        TabView {
            TorrentsTabView()
                .tabItem {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Torrents")
                }
            SettingsTabView(presenter: SettingsPresenter(managedObjectContext: managedObjectContext))
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Settings")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView()
    }
}
