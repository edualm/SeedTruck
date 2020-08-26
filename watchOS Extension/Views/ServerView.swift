//
//  ServerView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerView: View {
    
    @Binding var server: Server?
    
    var body: some View {
        TorrentListView(server: $server, filter: .constant(nil))
            .navigationBarTitle(server?.name ?? "Torrents")
    }
}

struct ServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerView(server: .constant(PreviewMockData.server))
    }
}
