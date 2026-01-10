//
//  LabelPickerView.swift
//  SeedTruck
//
//  Created by Claude on 20/08/2025.
//

import SwiftUI

struct LabelPickerView: View {
    
    @Binding var selectedLabels: [String]
    @State private var serverLabels: [String] = []
    @State private var isLoading: Bool = true
    
    let server: Server?
    
    init(selectedLabels: Binding<[String]>, server: Server? = nil) {
        self._selectedLabels = selectedLabels
        self.server = server
    }
    
    var hasLabels: Bool {
        !serverLabels.isEmpty
    }
    
    var body: some View {
        Group {
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading labels...")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .onAppear {
                    loadLabelsFromServer()
                }
            } else if hasLabels {
                ForEach(serverLabels, id: \.self) { label in
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
                            Spacer()
                            if selectedLabels.contains(label) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .foregroundColor(.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    #endif
                }
            } else {
                Text("No labels available")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
    
    private func loadLabelsFromServer() {
        guard let server = server else {
            serverLabels = []
            
            return
        }
        
        server.connection.getTorrents { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let torrents):
                    let allLabels = torrents.flatMap { $0.labels }
                    let uniqueLabels = Array(Set(allLabels)).sorted()
                    
                    self.serverLabels = uniqueLabels
                    
                case .failure(_):
                    self.serverLabels = []
                }
            }
        }
    }
}

struct LabelPickerView_Previews: PreviewProvider {
    
    static var previews: some View {
        LabelPickerView(selectedLabels: .constant(["Movies", "Work"]))
    }
}
