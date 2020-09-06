//
//  NoServersConfiguredView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NoServersConfiguredView: View {
    
    var body: some View {
        VStack {
            Spacer()
            Text("😞")
                .font(.largeTitle)
            Text("No servers configured!")
                .font(.headline)
                .padding()
            Text("Please add a server using the Settings tab.")
                .fontWeight(.light)
            Spacer()
        }
    }
}

struct NoServersConfiguredView_Previews: PreviewProvider {
    
    static var previews: some View {
        NoServersConfiguredView()
    }
}
