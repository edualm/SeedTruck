//
//  TorrentDetailsActionHandler.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation

class TorrentDetailsActionHandler: ObservableObject {
    
    enum Action {
        
        case abort
        case commit
        case pause
        case start
        
        case prepareForRemoval(deletingFiles: Bool)
    }
    
    struct AlertIdentifier: Identifiable {
        
        enum Choice {
            case confirmation
            case error
        }
        
        var id: Choice
    }
    
    let server: Server
    let torrent: RemoteTorrent
    
    private var actionToCommit: Action?
    
    @Published var currentAlert: AlertIdentifier? = nil
    
    init(server: Server, torrent: RemoteTorrent) {
        self.server = server
        self.torrent = torrent
    }
    
    func perform(_ action: Action, onSuccess: (() -> ())? = nil) {
        let successCheck: ((Result<Bool, ServerCommunicationError>) -> ()) = {
            if case let Result.success(success) = $0, success {
                DispatchQueue.main.async {
                    self.currentAlert = nil
                    
                    onSuccess?()
                }
            }
        }
        
        switch action {
        case .abort:
            actionToCommit = nil
            currentAlert = nil
            
        case .commit:
            switch actionToCommit {
            case .abort, .commit, .pause, .start, .none:
                assertionFailure("Can't commit an un-commitable mode!")
                
                return
                
            case .prepareForRemoval(let deletingFiles):
                server.connection.perform(.remove(deletingData: deletingFiles), on: torrent) {
                    self.actionToCommit = nil
                    
                    successCheck($0)
                    
                    self.currentAlert = .init(id: .error)
                }
            }
            
        case .pause:
            server.connection.perform(.pause, on: torrent, completionHandler: successCheck)
            
        case .start:
            server.connection.perform(.start, on: torrent, completionHandler: successCheck)
            
        case .prepareForRemoval:
            actionToCommit = action
            currentAlert = .init(id: .confirmation)
        }
    }
}
