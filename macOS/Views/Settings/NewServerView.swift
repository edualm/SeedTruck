//
//  NewServerView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
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
    
    @State var done: Bool = false
    
    var body: some View {
        if done {
            NewServerDoneView(done: $done)
        } else {
            Form {
                Section(header: Text("Metadata").font(.headline)) {
                    TextField("Name", text: $name)
                }
                
                Divider()
                    .padding([.top, .bottom])
                
                Section(header: Text("Connection Info").font(.headline)) {
                    Picker(selection: $type, label: EmptyView()) {
                        ForEach(0 ..< ServerType.allCases.count, id: \.self) {
                            Text(ServerType.allCases[$0].rawValue)
                        }
                    }
                    TextField("Endpoint", text: $endpoint)
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)
                }
                
                Divider()
                    .padding([.top, .bottom])
                
                Section {
                    HStack {
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
                        
                        Spacer()
                        
                        Button(action: { save(onSuccess: { done = true }) }) {
                            Label("Save", systemImage: "tag")
                        }
                    }
                }
            }
            .padding(.leading)
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
        }
    }
}

struct NewServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        NewServerView()
    }
}
