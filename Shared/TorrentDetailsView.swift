//
//  TorrentDetailsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentDetailsView: View {
    
    let torrent: RemoteTorrent
    
    var body: some View {
        ScrollView {
            GroupBox(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
                HStack {
                    Text(torrent.name)
                    Spacer()
                }.padding(.top)
            }
            GroupBox(label: Label("Status", systemImage: "exclamationmark.bubble")) {
                HStack {
                    Text(torrent.status.displayableStatus)
                    Spacer()
                }.padding(.top)
            }
            GroupBox(label: Label("Speed", systemImage: "speedometer")) {
                HStack {
                    VStack(alignment: .leading) {
                        Label("Download: 10 MB/s", systemImage: "chevron.down")
                        Label("Upload: 10 MB/s", systemImage: "chevron.up")
                    }
                    Spacer()
                }.padding(.top)
            }
            GroupBox(label: Label("Actions", systemImage: "wrench")) {
                HStack {
                    Button("Remove Torrent") {
                        
                    }
                }.padding(.top)
            }
        }
        .padding()
        .navigationBarTitle("Torrent Detail")
    }
}

struct TorrentDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentDetailsView(torrent: PreviewMockData.torrent)
            
    }
}
