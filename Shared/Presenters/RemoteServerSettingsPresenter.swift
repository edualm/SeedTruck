//
//  RemoteServerSettingsPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 04/10/2021.
//

import Foundation

class RemoteServerSettingsPresenter: ObservableObject {
    
    enum Action {
        
        case toggleDownSpeedLimit
        case toggleUpSpeedLimit
    }
    
    enum SpeedLimit {
        
        enum Configuration {
            
            case configured(down: Double, up: Double)
            case notConfigured
        }
        
        struct State {
            
            let down: Bool
            let up: Bool
        }
    }
    
    let server: Server
    
    @Published var hasServerSupport: Bool = true
    @Published var isErrored: Bool = false
    @Published var isLoading: Bool = true
    
    @Published var speedLimitConfiguration: SpeedLimit.Configuration?
    @Published var speedLimitState: SpeedLimit.State?
    
    init(server: Server) {
        self.server = server
        
        acquireData()
    }
    
    private func acquireData() {
        if let connection = server.connection as? HasSpeedLimitSupport {
            connection.getSpeedLimitConfiguration { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success((let down, let up)):
                        if down == 0 && up == 0 {
                            self.speedLimitConfiguration = .notConfigured
                        } else {
                            self.speedLimitConfiguration = .configured(down: down, up: up)
                        }
                        
                        if self.speedLimitConfiguration != nil && self.speedLimitState != nil {
                            self.isLoading = false
                        }
                        
                    case .failure:
                        self.isErrored = true
                        self.isLoading = false
                    }
                }
            }
            
            connection.getSpeedLimitState { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success((let down, let up)):
                        self.speedLimitState = .init(down: down, up: up)
                        
                        if self.speedLimitConfiguration != nil && self.speedLimitState != nil {
                            self.isLoading = false
                        }
                        
                    case .failure:
                        self.isErrored = true
                        self.isLoading = false
                    }
                }
            }
        } else {
            hasServerSupport = false
            isLoading = false
        }
    }
    
    func perform(_ action: Action) {
        guard let speedLimitState = speedLimitState else {
            //  TODO: Error handling.
            
            return
        }
        
        switch action {
        case .toggleDownSpeedLimit:
            if let connection = server.connection as? HasSpeedLimitSupport {
                connection.setSpeedLimitState((!speedLimitState.down, speedLimitState.up)) { result in
                    switch result {
                    case .success:
                        self.acquireData()
                    case .failure:
                        //  TODO: Error handling.
                        
                        break
                    }
                }
            }
            
            break
            
        case .toggleUpSpeedLimit:
            if let connection = server.connection as? HasSpeedLimitSupport {
                connection.setSpeedLimitState((speedLimitState.down, !speedLimitState.up)) { result in
                    switch result {
                    case .success:
                        self.acquireData()
                    case .failure:
                        //  TODO: Error handling.
                        
                        break
                    }
                }
            }
            
            break
        }
    }
}
