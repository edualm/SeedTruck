//
//  ProgressBarView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct ProgressBarView: View {
    
    let cornerRadius: CGFloat
    let barColorBuilder: ((CGFloat) -> (Color))
    
    let progress: CGFloat
    var accessibilityTitle = "Download progress"

    var normalizedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    var percentageLabel: String {
        String(format: "%.0f%%", normalizedProgress * 100)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.2))

                if normalizedProgress > 0 {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(barColorBuilder(normalizedProgress))
                        .frame(width: geometry.size.width * normalizedProgress)
                }

                Text(percentageLabel)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityRepresentation {
            ProgressView(value: Double(normalizedProgress), total: 1) {
                Text(accessibilityTitle)
            }
            .accessibilityValue(percentageLabel)
        }
    }
}

struct ProgressBarView_Previews: PreviewProvider {
    
    static private let defaultBarColorBuilder: ((CGFloat) -> (Color)) = { $0 < 1 ? .blue : .green }
    
    static var previews: some View {
        Group {
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 0)
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 0.1)
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 0.5)
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 1)
        }.previewLayout(.fixed(width: 300, height: 20))
    }
}
