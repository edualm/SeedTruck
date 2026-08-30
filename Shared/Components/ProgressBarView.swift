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
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))

                if normalizedProgress > 0 {
                    Rectangle()
                        .fill(barColorBuilder(normalizedProgress))
                        .frame(width: geometry.size.width * normalizedProgress)
                }

                Text(percentageLabel)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
        VStack(spacing: 8) {
            ForEach([CGFloat(0), 0.01, 0.03, 0.1, 0.5, 1], id: \.self) { progress in
                ProgressBarView(
                    cornerRadius: 10.0,
                    barColorBuilder: defaultBarColorBuilder,
                    progress: progress
                )
                .frame(height: 20)
            }
        }
        .frame(width: 300)
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
