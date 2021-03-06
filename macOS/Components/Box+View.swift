//
//  Box+View.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 19/09/2020.
//

import SwiftUI

extension Box: View {
    
    var body: some View {
        GroupBox(label: label) {
            content
                .padding(.bottom)
        }
    }
}

struct Box_Previews: PreviewProvider {

    static var previews: some View {
        Box(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
            Text("Foo")
        }
    }
}
