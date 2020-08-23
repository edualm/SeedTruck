//
//  MainView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct MainView: View {
    
    var body: some View {
        TabView {
            TorrentsView()
                .tabItem {
                    Image(systemName: "arrow.down.doc")
                    Text("Torrents")
                }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static var previews: some View {
        MainView()
    }
}
