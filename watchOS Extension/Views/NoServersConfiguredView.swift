//
//  NoServersConfiguredView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 31/08/2020.
//

import SwiftUI

struct NoServersConfiguredView: View {
    
    var body: some View {
        VStack {
            Text("No servers!")
                .font(.headline)
                .padding()
            Text("Please configure at least one server using your iPhone and then try again.")
                .fontWeight(.light)
                .multilineTextAlignment(.center)
        }
    }
}

struct NoServersConfiguredView_Previews: PreviewProvider {
    
    static var previews: some View {
        NoServersConfiguredView()
    }
}
