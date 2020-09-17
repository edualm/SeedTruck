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
    @Environment(\.presentationMode) private var presentation
    
    @State private var name = ""
    @State private var endpoint = ""
    @State private var type = 0
    @State private var username = ""
    @State private var password = ""
    
    @State private var showingAlert: AlertIdentifier?
    
    var server: TemporaryServer? {
        guard let endpoint = URL(string: endpoint) else {
            return nil
        }
        
        return TemporaryServer(endpoint: endpoint,
                               name: name,
                               type: Int16(type),
                               credentialUsername: !username.isEmpty ? username : nil,
                               credentialPassword: !password.isEmpty ? password : nil)
    }
    
    func testConnection(completion: @escaping (Bool) -> ()) {
        guard let server = server else {
            completion(false)
            
            return
        }
        
        server.connection.test { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    func save() {
        guard let server = server else {
            showingAlert = .init(id: .failure)
            
            return
        }
        
        do {
            let coreDataServer = server.convertToServer(withManagedContext: managedObjectContext)
            
            managedObjectContext.insert(coreDataServer)
            
            try managedObjectContext.save()
            
            self.presentation.wrappedValue.dismiss()
        } catch {
            showingAlert = .init(id: .failure)
        }
    }
    
    var body: some View {
        var form = Form {
            Section(header: Text("Metadata")) {
                TextField("Name", text: $name)
            }
            
            Section(header: Text("Connection Info")) {
                Picker(selection: $type, label: Text("Type")) {
                    ForEach(0 ..< ServerType.allCases.count) {
                        Text(ServerType.allCases[$0].rawValue)
                    }
                }
                #if os(macOS)
                TextField("Endpoint", text: $endpoint)
                #else
                TextField("Endpoint", text: $endpoint)
                    .keyboardType(.URL)
                #endif
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
        
        #if os(macOS)
        return form
        #else
        return form.navigationBarTitle("New Server")
        #endif
    }
}

struct NewServerView_Previews: PreviewProvider {
    
    static var previews: some View {
        NewServerView()
    }
}
