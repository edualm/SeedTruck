//
//  MainView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct MainView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var body: some View {
        if #available(iOS 26.0, *) {
            TabView {
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
                }.toolbar(.visible, for: .tabBar)
            }
            .tabViewBottomAccessory {
                FloatingServerStatusView(torrents: [])
            }
        } else {
            TabView {
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
                }.toolbar(.visible, for: .tabBar)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView()
    }
}
