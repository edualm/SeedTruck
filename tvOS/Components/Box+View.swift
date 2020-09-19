//
//  Box+View.swift
//  SeedTruck (tvOS)
//
//  Created by Eduardo Almeida on 19/09/2020.
//

import SwiftUI

extension Box: View {
    
    var body: some View {
        HStack(alignment: .center) {
            label
            Spacer()
            content
                .padding(.bottom, 16)
        }
    }
}

struct Box_Previews: PreviewProvider {

    static var previews: some View {
        Box(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
            Text("Foo")
        }.previewDevice(.init(rawValue: "Apple TV 4K") )
    }
}
