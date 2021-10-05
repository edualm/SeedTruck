//
//  ErrorView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct ErrorView: View {
    
    enum ErrorType {
        
        case noConnection
        case notSupported
    }
    
    let type: ErrorType
    
    var body: some View {
        VStack {
            Spacer()
            
            Image(systemName: "questionmark.folder")
                .font(.largeTitle)
            
            Text("Error!")
                .font(.headline)
                .padding()
            
            switch type {
            case .noConnection:
                Text("Data could not be retrieved from the server.")
                    .fontWeight(.light)
            case .notSupported:
                Text("The server does not support the requested functionality.")
                    .fontWeight(.light)
            }
            
            Spacer()
        }
    }
}

struct ServerConnectionErrorView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            ErrorView(type: .noConnection)
            ErrorView(type: .notSupported)
        }
    }
}
