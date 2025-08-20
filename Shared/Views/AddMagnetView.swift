//
//  AddMagnetView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct AddMagnetView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    @State private var magnetLink: String = ""
    @State private var selectedLabels: [String] = []
    @State private var navigationLinkActive = false
    @State private var showingErrorAlert = false
    @State private var hasServerLabels: Bool = false
    
    @Binding var server: Server?
    
    @ViewBuilder
    var innerBody: some View {
        Form {
            Section {
                HStack {
                    Label("What is this?", systemImage: "questionmark.circle")
                        .font(.headline)
                    Spacer()
                }.padding(.vertical, 4)
                Text("Add a magnet link to your remote torrent client by simply pasting the link below!")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            
            Section("Magnet Link") {
                TextField("Magnet Link", text: $magnetLink)
            }
            
            if hasServerLabels {
                Section("Labels (Optional)") {
                    LabelPickerView(selectedLabels: $selectedLabels, server: server)
                }
            }
            
            Section {
                NavigationLink(destination:
                    TorrentHandlerView(torrent: .magnet(magnetLink, labels: selectedLabels),
                                                    server: server,
                                                    closeHandler: {
                                                        DispatchQueue.main.async {
                                                            NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
                                                        }
                                                        
                                                        #if os(macOS)
                                                        Application.closeMainWindow()
                                                        #else
                                                        presentation.wrappedValue.dismiss()
                                                        #endif
                                                    })
                ) {
                    Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                }
            }
        }
    }
    
    private func loadLabelsFromServer() {
        guard let server = server else {
            hasServerLabels = false
            return
        }
        
        server.connection.getTorrents { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let torrents):
                    let allLabels = torrents.flatMap { $0.labels }
                    let uniqueLabels = Array(Set(allLabels)).sorted()
                    hasServerLabels = !uniqueLabels.isEmpty
                    
                case .failure(_):
                    hasServerLabels = false
                }
            }
        }
    }
    
    @ViewBuilder
    var body: some View {
        NavigationView {
            #if os(macOS)
            innerBody
                .navigationTitle("Add Magnet")
            #else
            innerBody
                .navigationTitle("Add Magnet")
                .navigationBarItems(trailing: Button(action: {
                    self.presentation.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .fontWeight(.medium)
                })
            #endif
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(title: Text("Error!"),
                  message: Text("An error has occurred while processing the requested magnet link."),
                  dismissButton: .cancel())
        }
        .onAppear {
            loadLabelsFromServer()
        }
        
    }
}

struct AddMagnetView_Previews: PreviewProvider {
    
    static var previews: some View {
        AddMagnetView(server: .constant(PreviewMockData.server))
    }
}
