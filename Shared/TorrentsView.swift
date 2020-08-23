//
//  TorrentsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentsView: View {
    
    @StateObject var presenter: TorrentsViewPresenter = TorrentsViewPresenter()
    
    //  TODO: If has various seedboxes, present hamburger icon. Else, show EmptyView
    
    var body: some View {
        NavigationView {
            List {
                ForEach([0, 1, 5, 9, 10], id: \.self) {
                    TorrentItemView(name: "Torrent Name", progress: CGFloat($0) * 0.1)
                        .padding(.all, 5)
                }
            }
            .navigationTitle("Torrents")
            .navigationBarItems(leading: Button(action: {
                presenter.perform(.addTorrent)
            }) {
                Image(systemName: "text.justify")
            }, trailing: Button(action: {
                presenter.perform(.addTorrent)
            }) {
                Image(systemName: "plus")
            })
        }
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentsView()
    }
}
