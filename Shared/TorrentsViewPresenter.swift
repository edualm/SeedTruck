//
//  TorrentsViewPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

class TorrentsViewPresenter: ObservableObject {
    
    struct ViewModel {
        
        let servers: [Server]
        
        let currentServer: Server?
    }
    
    @Published var viewModel: ViewModel
    
    init(viewModel: ViewModel = ViewModel(servers: [], currentServer: nil)) {
        self.viewModel = viewModel
    }
    
    enum Action {
        
        case addTorrent
        case changeSeedbox
        case toggleChangeSeedboxListVisibility
    }
    
    func perform(_ action: Action) {
        switch action {
        case .addTorrent:
            ()
        case .changeSeedbox:
            ()
        case .toggleChangeSeedboxListVisibility:
            ()
        }
    }
}
