//
//  NewServerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NewServerView: View {
    
    private struct AlertIdentifier: Identifiable {
        enum Choice {
            case failure
            case success
        }
        
        var id: Choice
    }
    
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State private var name = ""
    @State private var endpoint = ""
    @State private var type = 0
    @State private var username = ""
    @State private var password = ""
    
    @State private var showingAlert: AlertIdentifier?
    
    @Binding var showing: Bool
    
    var server: Server? {
        guard let endpoint = URL(string: endpoint) else {
            return nil
        }
        
        let newServer = Server.new(withManagedContext: managedObjectContext)
        
        newServer.name = name
        newServer.endpoint = endpoint
        newServer.type = Int16(type)
        
        newServer.credentialUsername = !username.isEmpty ? username : nil
        newServer.credentialPassword = !password.isEmpty ? password : nil
        
        return newServer
    }
    
    func testConnection(completion: @escaping (Bool) -> ()) {
        guard let server = server else {
            completion(false)
            
            return
        }
        
        server.connection.getTorrents { result in
            DispatchQueue.main.async {
                defer {
                    managedObjectContext.delete(server)
                }
                
                guard case Result.success = result else {
                    completion(false)
                    
                    return
                }
                
                completion(true)
            }
        }
    }
    
    func save() {
        guard let server = server else {
            showingAlert = .init(id: .failure)
            
            return
        }
        
        showing = false
        
        //  Mjölnir 🔨
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
            managedObjectContext.insert(server)
            
            try! managedObjectContext.save()
        }
    }
    
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
                TextField("Username", text: $username)
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
                
                Button(action: save) {
                    Label("Save", systemImage: "tag")
                }
            }
        }
        .navigationBarTitle("New Server")
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

struct NewServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        NewServerView(showing: .constant(true))
    }
}
