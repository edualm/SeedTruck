//
//  CompactLabelStyle.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 09/02/2026.
//

import SwiftUI

struct CompactLabelStyle: LabelStyle {
    
    var spacing: CGFloat = 4.0
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}
