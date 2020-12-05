//
//  NoTorrentsView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 05/12/2020.
//

import SwiftUI

struct NoTorrentsView: View {
    
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "tray")
                .font(.largeTitle)
            Text("Nothing to show!")
                .font(.headline)
                .padding()
            Text("There are no torrents to show on the given server/filter.")
                .fontWeight(.light)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

struct NoTorrentsView_Previews: PreviewProvider {
    static var previews: some View {
        NoTorrentsView()
    }
}
