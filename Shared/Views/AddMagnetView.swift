//
//  AddMagnetView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct AddMagnetView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    @State private var isLoading = false
    @State private var magnetLink: String = ""
    @State private var showingErrorAlert = false
    
    @Binding var server: Server?
    
    var body: some View {
        var innerView = ScrollView {
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
                        self.presentation.wrappedValue.dismiss()
                        
                    case .failure:
                        showingErrorAlert = true
                    }
                }
            }) {
                Text("Start Download")
            }
        }
        .navigationTitle("Add Magnet")
        
        #if !os(macOS)
        
        innerView = innerView.navigationBarItems(trailing: Button(action: {
            self.presentation.wrappedValue.dismiss()
        }) {
            Text("Cancel")
                .fontWeight(.medium)
        })
        
        #endif
        
        NavigationView {
            if isLoading {
                ProgressView {
                    Text("Processing...")
                }
            } else {
                innerView
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
        AddMagnetView(server: .constant(PreviewMockData.server))
    }
}
