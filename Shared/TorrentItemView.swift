//
//  TorrentItemView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentItemView: View {
    
    @State var name: String
    @State var progress: CGFloat
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
                .bold()
            ProgressBarView(cornerRadius: 10.0, progress: progress)
                .frame(width: nil, height: 20, alignment: .center)
            HStack {
                Label("10 MB/s", systemImage: "chevron.down")
                    .font(.footnote)
                Label("10 MB/s", systemImage: "chevron.up")
                    .font(.footnote)
            }
        }
    }
}

struct TorrentItemView_Previews: PreviewProvider {
    static var previews: some View {
        TorrentItemView(name: "Super Legal Movie [WEB-DL].mkv", progress: 0.5)
    }
}
