//
//  ServerConnectionErrorView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct ServerConnectionErrorView: View {
    
    var body: some View {
        VStack {
            Text("😞")
                .font(.largeTitle)
            Text("Error!")
                .font(.headline)
                .padding()
            Text("Data could not be retrieved from the server.")
                .fontWeight(.light)
        }
    }
}

struct ServerConnectionErrorView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerConnectionErrorView()
    }
}
