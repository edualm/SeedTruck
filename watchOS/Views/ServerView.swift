//
//  ServerView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerView: View {
    
    @Binding var server: Server?
    
    let shouldShowBackButton: Bool
    
    var body: some View {
        TorrentListView(server: $server, filter: .constant(nil), filterQuery: .constant(""), selectedTorrentId: .constant(nil))
            .navigationBarTitle(server?.name ?? "Torrents")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(!shouldShowBackButton)
    }
}

struct ServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerView(server: .constant(PreviewMockData.server),
                   shouldShowBackButton: false)
    }
}
