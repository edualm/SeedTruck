//
//  NewServerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NewServerView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.presentationMode) var presentation
    
    @State var name = ""
    @State var endpoint = ""
    @State var type = 0
    @State var username = ""
    @State var password = ""
    
    @State var showingAlert: AlertIdentifier?
    
    var body: some View {
        Form {
            Section(header: Text("Metadata")) {
                TextField("Name", text: $name)
            }
            
            Section(header: Text("Connection Info")) {
                Picker(selection: $type, label: Text("Type")) {
                    ForEach(0 ..< ServerType.allCases.count) {
                        Text(ServerType.allCases[$0].rawValue)
                    }
                }
                TextField("Endpoint", text: $endpoint)
                    .keyboardType(.URL)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                TextField("Username", text: $username)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
            }
            
            Section {
                Button(action: {
                    testConnection {
                        if $0 {
                            showingAlert = .init(id: .success)
                        } else {
                            showingAlert = .init(id: .failure)
                        }
                    }
                }) {
                    Label("Test Connection", systemImage: "wand.and.rays")
                }
                
                Button(action: { save(onSuccess: { self.presentation.wrappedValue.dismiss() }) }) {
                    Label("Save", systemImage: "tag")
                }
            }
        }
        .alert(item: $showingAlert) {
            switch $0.id {
            case .success:
                return Alert(title: Text("Success!"),
                      message: Text("Connection established successfully."),
                      dismissButton: .default(Text("Ok")))
                
            case .failure:
                return Alert(title: Text("Error!"),
                      message: Text("Please verify the inserted data."),
                      dismissButton: .default(Text("Ok")))
            }
        }
        .navigationBarTitle("New Server")
    }
}

struct NewServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        NewServerView()
    }
}
