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
            Image(systemName: "globe")
                .font(.largeTitle)
            Text("Loading...")
                .font(.headline)
                .padding()
            Text("Your data's coming!")
                .fontWeight(.light)
        }
    }
}

struct LoadingView_Previews: PreviewProvider {
    
    static var previews: some View {
        LoadingView()
    }
}
