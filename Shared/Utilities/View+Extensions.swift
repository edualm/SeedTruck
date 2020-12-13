//
//  View+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 13/12/2020.
//

import SwiftUI

private struct Center: ViewModifier {
    
    func body(content: Content) -> some View {
        HStack {
            Spacer()
            content
            Spacer()
        }
    }
}

extension View {
    
    func centered() -> some View {
        self.modifier(Center())
    }
}
