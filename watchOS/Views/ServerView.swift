//
//  ServerView.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct ServerView: View {
    
    let server: Server
    
    let shouldShowBackButton: Bool
    
    var body: some View {
        TorrentListView(
            server: .constant(server),
            filter: .constant(nil),
            filterQuery: .constant(""),
            sort: .constant(.name),
            sortDirection: .constant(.ascending),
            selectedTorrentId: .constant(nil)
        )
            .navigationBarTitle(server.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(!shouldShowBackButton)
    }
}

struct ServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerView(server: PreviewMockData.server,
                   shouldShowBackButton: false)
    }
}
