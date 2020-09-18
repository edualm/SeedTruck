//
//  ProgressBarView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct ProgressBarView: View {
    
    let cornerRadius: CGFloat
    
    @State var progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                ZStack {
                    Rectangle()
                        .foregroundColor(progress > 0 ? .gray : .red)
                    HStack {
                        Rectangle()
                            .foregroundColor(progress < 1 ? .blue : .green)
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
    
    static var previews: some View {
        Group {
            ProgressBarView(cornerRadius: 10.0, progress: 0)
            ProgressBarView(cornerRadius: 10.0, progress: 0.5)
            ProgressBarView(cornerRadius: 10.0, progress: 1)
        }.previewLayout(.fixed(width: 300, height: 10))
    }
}
