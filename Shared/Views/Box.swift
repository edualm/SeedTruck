//
//  Box.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct Box<Label: View, Content: View>: View {
    
    let label: Label
    let content: Content
    
    init(label: Label, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        #if !os(watchOS)
        GroupBox(label: label) {
            content
        }
        #else
        VStack {
            HStack {
                label
                Spacer()
            }
            content
        }
        #endif
    }
}

struct Box_Previews: PreviewProvider {
    
    static var previews: some View {
        Box(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
            Text("Foo")
        }.previewDevice(.init(rawValue: "Apple Watch Series 5 - 44mm") )
    }
}