//
//  NoServersConfiguredView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NoServersConfiguredView: View {
    
    var text: Text {
        #if os(macOS)
        Text("Please add a server using the Settings window of the app.")
        #else
        Text("Please add a server using the Settings tab.")
        #endif
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text("😞")
                .font(.largeTitle)
            Text("No servers configured!")
                .font(.headline)
                .padding()
            text
                .fontWeight(.light)
                .multilineTextAlignment(.center)
                .padding([.leading, .trailing])
            Spacer()
        }
    }
}

struct NoServersConfiguredView_Previews: PreviewProvider {
    
    static var previews: some View {
        NoServersConfiguredView()
    }
}
