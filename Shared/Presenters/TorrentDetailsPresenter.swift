//
//  TorrentDetailsPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation

class TorrentDetailsPresenter: ObservableObject {
    
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
    @Published var isLoading: Bool = false
    
    init(server: Server, torrent: RemoteTorrent) {
        self.server = server
        self.torrent = torrent
    }
    
    func perform(_ action: Action, onSuccess: (() -> ())? = nil) {
        let successCheck: ((Result<Bool, ServerCommunicationError>) -> ()) = { result in
            DispatchQueue.main.async {
                if case let Result.success(success) = result, success {
                    self.currentAlert = nil
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
                    }
                    
                    onSuccess?()
                } else {
                    self.currentAlert = .init(id: .error)
                    
                    self.isLoading = false
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
                server.connection.perform(.remove(deletingData: deletingFiles), on: torrent, completionHandler: successCheck)
                
                actionToCommit = nil
                isLoading = true
            }
            
        case .pause:
            server.connection.perform(.pause, on: torrent, completionHandler: successCheck)
            
            isLoading = true
            
        case .start:
            server.connection.perform(.start, on: torrent, completionHandler: successCheck)
            
            isLoading = true
            
        case .prepareForRemoval:
            actionToCommit = action
            currentAlert = .init(id: .confirmation)
        }
    }
}
