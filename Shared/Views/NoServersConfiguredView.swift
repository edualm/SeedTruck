//
//  NoServersConfiguredView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NoServersConfiguredView: View {
    
    var body: some View {
        #if !os(watchOS)
        VStack {
            Text("😞")
                .font(.largeTitle)
            Text("No servers configured!")
                .font(.headline)
                .padding()
            Text("Please add a server using the Settings tab.")
                .fontWeight(.light)
        }
        #else
        VStack {
            Text("No servers!")
                .font(.headline)
                .padding()
            Text("Please configure at least one server using your iPhone and then try again.")
                .fontWeight(.light)
                .multilineTextAlignment(.center)
        }
        #endif
    }
}

struct NoServersConfiguredView_Previews: PreviewProvider {
    
    static var previews: some View {
        NoServersConfiguredView()
    }
}
