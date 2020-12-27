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
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                ZStack {
                    Rectangle()
                        .foregroundColor(progress > 0 ? .gray : .red)
                    HStack {
                        Rectangle()
                            .foregroundColor(barColorBuilder(progress))
                            .frame(minWidth: geometry.size.width * progress,
                                   idealWidth: geometry.size.width * progress,
                                   maxWidth: geometry.size.width * progress)
                        Spacer()
                            .frame(minWidth: 0)
                    }
                }.cornerRadius(cornerRadius)
            }
        }
    }
}

struct ProgressBarView_Previews: PreviewProvider {
    
    static private let defaultBarColorBuilder: ((CGFloat) -> (Color)) = { $0 < 1 ? .blue : .green }
    
    static var previews: some View {
        Group {
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 0)
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 0.5)
            ProgressBarView(cornerRadius: 10.0, barColorBuilder: defaultBarColorBuilder, progress: 1)
        }.previewLayout(.fixed(width: 300, height: 10))
    }
}
