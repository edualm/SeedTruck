//
//  LoadingView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct LoadingView: View {
    
    var body: some View {
        VStack {
            Spacer()
            #if os(watchOS)
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Loading torrents")
            #else
            ProgressView("Loading torrents...")
                .font(.headline)
                .padding()
            #endif
            Spacer()
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    
    static var previews: some View {
        LoadingView()
    }
}
