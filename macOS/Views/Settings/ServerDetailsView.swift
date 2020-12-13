//
//  ServerDetailsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct ServerDetailsView: View {
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    let server: Server
    
    @State private var connectionResult: ConnectionResult = .connecting
    @State private var isActive: Bool = true
    @State private var showingDeleteAlert: Bool = false
    
    init(server: Server) {
        self.server = server
    }
    
    func onAppear() {
        server.connection.test { success in
            connectionResult = success ? .success : .failure
        }
    }
    
    func deleteServer() {
        managedObjectContext.delete(server)
        try! managedObjectContext.save()
        
        isActive = false
    }
    
    var body: some View {
        if !isActive {
            EmptyView()
        } else {
            VStack {
                HStack {
                    Text("Connection Status:")
                    switch connectionResult {
                    case .connecting:
                        Text("...")
                    case .failure:
                        Text("Failed!")
                            .foregroundColor(.red)
                    case .success:
                        Text("Success!")
                            .foregroundColor(.init(.systemGreen))
                    }
                }
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.primary, lineWidth: 2)
                )
                
                Divider()
                    .padding([.top, .bottom])
                
                Label("To edit a connection, just delete and create it again.", systemImage: "pencil")
                    .padding([.leading, .trailing, .bottom])
                
                Button {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundColor(.red)
                .alert(isPresented: $showingDeleteAlert) {
                    Alert(title: Text("Are you sure you want to delete \"\(server.name)\"?"),
                          message: nil,
                          primaryButton: .destructive(Text("Delete")) {
                            deleteServer()
                          },
                          secondaryButton: .cancel() {})
                }
            }
            .padding()
            .onAppear(perform: onAppear)
        }
    }
}

struct ServerDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        ServerDetailsView(server: PreviewMockData.server)
    }
}
