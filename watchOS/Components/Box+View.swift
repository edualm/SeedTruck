//
//  Box+View.swift
//  SeedTruck (watchOS) Extension
//
//  Created by Eduardo Almeida on 19/09/2020.
//

import SwiftUI

extension Box: View {
    
    var body: some View {
        VStack {
            HStack {
                label
                Spacer()
            }
            content
        }
    }
}

struct Box_Previews: PreviewProvider {

    static var previews: some View {
        Box(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
            Text("Foo")
        }.previewDevice(.init(rawValue: "Apple Watch Series 5 - 44mm") )
    }
}
