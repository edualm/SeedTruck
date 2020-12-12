//
//  NewServerView+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import Foundation

extension NewServerView {
    
    struct AlertIdentifier: Identifiable {
        enum Choice {
            case failure
            case success
        }
        
        var id: Choice
    }
    
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
    
    func save(onSuccess: (() -> ())?) {
        guard let server = server else {
            showingAlert = .init(id: .failure)
            
            return
        }
        
        do {
            let coreDataServer = server.convertToServer(withManagedContext: managedObjectContext)
            
            managedObjectContext.insert(coreDataServer)
            
            try managedObjectContext.save()
            
            onSuccess?()
        } catch {
            showingAlert = .init(id: .failure)
        }
    }
}
