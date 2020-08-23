//
//  TorrentsViewPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

class TorrentsViewPresenter: ObservableObject {
    
    enum Action {
        case addTorrent
    }
    
    func perform(_ action: Action) {
        switch action {
        case .addTorrent:
            ()
        }
    }
}
