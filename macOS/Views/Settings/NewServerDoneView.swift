//
//  NewServerDoneView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct NewServerDoneView: View {
    
    @Binding var done: Bool
    
    var body: some View {
        VStack {
            Image(systemName: "checkmark")
                .font(.largeTitle)
            
            Text("Done!")
                .font(.title)
                .padding()
            
            Text("Server added successfully!")
                .padding()
            
            Button {
                done = false
            } label: {
                Text("Add another?")
            }
            .padding()
        }
    }
}

struct NewServerDoneView_Previews: PreviewProvider {
    static var previews: some View {
        NewServerDoneView(done: .constant(true))
    }
}
