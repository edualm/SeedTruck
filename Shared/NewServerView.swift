//
//  NewServerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NewServerView: View {
    
    struct AlertIdentifier: Identifiable {
        enum Choice {
            case failure
            case success
        }
        
        var id: Choice
    }
    
    @Environment(\.managedObjectContext) var managedObjectContext
    
    @State var name = ""
    @State var endpoint = ""
    @State var type = 0
    @State var username = ""
    @State var password = ""
    
    @State var showingAlert: AlertIdentifier?
    
    var server: Server? {
        let type: ServerType = ServerType(fromCode: self.type)!
        
        guard let endpoint = URL(string: endpoint) else {
            return nil
        }
        
        let credentials: URLCredential?
        
        if username != "" && password != "" {
            credentials = URLCredential(user: username, password: password, persistence: .none)
        } else {
            credentials = nil
        }
        
        return Server(name: name,
                      connectionDetails: .init(type: type,
                                               endpoint: endpoint,
                                               credentials: credentials))
    }
    
    func testConnection(completion: @escaping (Bool) -> ()) {
        guard let server = server else {
            completion(false)
            
            return
        }
        
        server.connection.getTorrents { result in
            DispatchQueue.main.async {
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
            showingAlert = AlertIdentifier(id: .failure)
            
            return
        }
        
        let newServer = ServerConnectionDetails(context: managedObjectContext)
        
        newServer.name = server.name
        newServer.endpoint = server.connectionDetails.endpoint
        newServer.type = server.connectionDetails.type.code
        
        newServer.credentialUsername = server.connectionDetails.credentials?.user
        newServer.credentialPassword = server.connectionDetails.credentials?.password
        
        try! managedObjectContext.save()
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
                TextField("Username", text: $username)
                TextField("Password", text: $password)
            }
            
            Section {
                Button(action: {
                    testConnection {
                        if $0 {
                            showingAlert = AlertIdentifier(id: .success)
                        } else {
                            showingAlert = AlertIdentifier(id: .failure)
                        }
                    }
                }) {
                    Label("Test Connection", systemImage: "wand.and.rays")
                }
                
                Button(action: {
                    
                }) {
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
        NewServerView()
    }
}
