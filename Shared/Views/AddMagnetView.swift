//
//  AddMagnetView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct AddMagnetView: View {
    
    @State private var isLoading = false
    @State private var magnetLink: String = ""
    @State private var showingErrorAlert = false
    
    @Binding var server: Server?
    @Binding var showing: Bool
    
    var body: some View {
        NavigationView {
            if isLoading {
                ProgressView {
                    Text("Processing...")
                }
            } else {
                ScrollView {
                    GroupBox(label: Label("What is this?", systemImage: "questionmark.circle")) {
                        HStack {
                            Text("Use this form to add a magnet link to your remote torrent client by simply pasting the link below!")
                            Spacer()
                        }.padding(.top)
                    }.padding()
                    
                    TextField("Magnet Link", text: $magnetLink)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    Button(action: {
                        isLoading = true
                        
                        server?.connection.addTorrent(.magnet(magnetLink)) {
                            isLoading = false
                            
                            switch $0 {
                            case .success:
                                showing = false
                            case .failure:
                                showingErrorAlert = true
                            }
                        }
                    }) {
                        Text("Add")
                    }
                }
                .navigationTitle("Add Magnet")
                .navigationBarItems(trailing: Button(action: {
                    showing = false
                }) {
                    Text("Cancel")
                        .fontWeight(.medium)
                })
            }
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(title: Text("Error!"),
                  message: Text("An error has occurred while processing the requested magnet link."),
                  dismissButton: .cancel())
        }
        
    }
}

struct AddMagnetView_Previews: PreviewProvider {
    
    static var previews: some View {
        AddMagnetView(server: .constant(PreviewMockData.server),
                      showing: .constant(true))
    }
}
