//
//  Box.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct Box<Label: View, Content: View> {
    
    let label: Label
    let content: Content
    
    init(label: Label, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
}
