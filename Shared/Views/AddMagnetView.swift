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
    @State private var navigationLinkActive = false
    @State private var showingErrorAlert = false
    
    @Binding var server: Server?
    
    @ViewBuilder
    var innerBody: some View {
        VStack {
            GroupBox(label: Label("What is this?", systemImage: "questionmark.circle")) {
                HStack {
                    Text("Use this form to add a magnet link to your remote torrent client by simply pasting the link below!")
                    Spacer()
                }.padding(.top)
            }.padding()
            
            TextField("Magnet Link", text: $magnetLink)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            NavigationLink(destination:
                TorrentHandlerView(torrent: .magnet(magnetLink),
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
                Text("Start Download")
            }
            
            Spacer()
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
        
    }
}

struct AddMagnetView_Previews: PreviewProvider {
    
    static var previews: some View {
        AddMagnetView(server: .constant(PreviewMockData.server))
    }
}
