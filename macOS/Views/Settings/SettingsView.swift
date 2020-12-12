//
//  SettingsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    private enum Tabs: Hashable {
        
        case general
        case servers
    }
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(Tabs.general)
            
            ServerSettingsView()
                .tabItem {
                    Label("Servers", systemImage: "server.rack")
                }
                .tag(Tabs.servers)
        }
        .padding(20)
        .frame(width: 700, height: 375)
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        SettingsView()
    }
}
