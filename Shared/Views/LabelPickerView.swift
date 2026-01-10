//
//  LabelPickerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 20/08/2025.
//

import SwiftUI

struct LabelPickerView: View {
    
    @Binding var selectedLabels: [String]
    
    let labels: [String]
    
    init(selectedLabels: Binding<[String]>, labels: [String]) {
        self._selectedLabels = selectedLabels
        self.labels = labels
    }
    
    var body: some View {
        ForEach(labels, id: \.self) { label in
            #if os(macOS)
            Toggle(isOn: Binding(
                get: { selectedLabels.contains(label) },
                set: { isSelected in
                    if isSelected {
                        if !selectedLabels.contains(label) {
                            selectedLabels.append(label)
                        }
                    } else {
                        selectedLabels.removeAll { $0 == label }
                    }
                }
            )) {
                Text(label)
                    .foregroundColor(.primary)
            }
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
            #else
            Button(action: {
                if selectedLabels.contains(label) {
                    selectedLabels.removeAll { $0 == label }
                } else {
                    selectedLabels.append(label)
                }
            }) {
                HStack {
                    Text(label)
                        .foregroundColor(.primary)
                    Spacer()
                    if selectedLabels.contains(label) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            #endif
        }
    }
}

struct LabelPickerView_Previews: PreviewProvider {
    
    static var previews: some View {
        LabelPickerView(
            selectedLabels: .constant(["Movies", "Work"]),
            labels: ["Movies", "Songs", "Work"],
        )
    }
}
