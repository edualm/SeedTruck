//
//  TorrentDetailsViewPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation

class TorrentDetailsViewPresenter: ObservableObject {
    
    enum Action {
        
        case abort
        case commit
        
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
    
    var actionToCommit: Action?
    
    @Published var currentAlert: AlertIdentifier? = nil
    
    init(server: Server, torrent: RemoteTorrent) {
        self.server = server
        self.torrent = torrent
    }
    
    func perform(_ action: Action, onSuccess: (() -> ())? = nil) {
        switch action {
        case .abort:
            actionToCommit = nil
            currentAlert = nil
            
        case .commit:
            switch actionToCommit {
            case .abort, .commit, .none:
                assertionFailure("Can't commit an un-commitable mode!")
                
                return
                
            case .prepareForRemoval(let deletingFiles):
                server.connection.removeTorrent(torrent,
                                                deletingData: deletingFiles) { result in
                    
                    self.actionToCommit = nil
                    
                    if case let Result.success(success) = result, success {
                        self.currentAlert = nil
                        
                        DispatchQueue.main.async {
                            onSuccess?()
                        }
                        
                        return
                    }
                    
                    self.currentAlert = .init(id: .error)
                }
            }
            
        case .prepareForRemoval:
            actionToCommit = action
            currentAlert = .init(id: .confirmation)
        }
    }
}
