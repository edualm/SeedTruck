//
//  TransmissionConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

class TransmissionConnection: ServerConnection {
    
    private typealias Parameters = Dictionary<String, Any>
    
    private enum Header: String {
        
        case Authorization = "Authorization"
        case CSRFToken = "X-Transmission-Session-Id"
        
        var name: String {
            return rawValue
        }
    }
    
    private enum TransmissionError: Error {
        case invalidRequest
        case invalidResponse
    }
    
    struct ConnectionDetails {
        
        struct Credentials {
            
            let username: String
            let password: String
            
            var base64Encoded: String {
                return "\(username):\(password)".data(using: .utf8)!.base64EncodedString()
            }
        }
        
        let endpoint: URL
        let credentials: Credentials?
    }
    
    static private let CSRFTokenHeaderName = "X-Transmission-Session-Id"
    
    static private let TorrentFields = ["id", "name", "percentDone", "status", "sizeWhenDone", "peersConnected", "rateUpload", "peersSendingToUs", "peersGettingFromUs", "rateDownload", "uploadedEver", "uploadRatio", "secondsSeeding", "eta", "etaIdle", "labels"]
    
    private let connectionDetails: ConnectionDetails
    private var csrfToken: String?
    
    init(connectionDetails: ConnectionDetails) {
        self.connectionDetails = connectionDetails
    }
    
    private func performCall<T: Decodable>(withMethod method: String, parameters: Dictionary<String, Any>?, completionHandler: @escaping (Result<T, TransmissionError>) -> ()) {
        let request: [String: Any] = [
            "method": method,
            "arguments": parameters as Any
        ]
        
        var urlRequest = URLRequest(url: connectionDetails.endpoint)
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: request, options: .init()) else {
            completionHandler(.failure(.invalidRequest))
            
            return
        }
        
        urlRequest.httpBody = httpBody
        urlRequest.httpMethod = "POST"
        
        if let credentials = connectionDetails.credentials {
            urlRequest.addValue("Basic \(credentials.base64Encoded)", forHTTPHeaderField: Header.Authorization.name)
        }
        
        if let csrfToken = csrfToken {
            urlRequest.addValue(csrfToken, forHTTPHeaderField: Header.CSRFToken.name)
        }
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 5.0
        sessionConfig.timeoutIntervalForResource = 10.0
        
        let task = URLSession(configuration: sessionConfig).dataTask(with: urlRequest) { [self] data, response, error in
            guard error == nil, let response = response as? HTTPURLResponse else {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            if response.statusCode == 403 || response.statusCode == 500 {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            guard response.statusCode != 409 else {
                if let newCSRFToken = response.allHeaderFields[Header.CSRFToken.name] as? String {
                    csrfToken = newCSRFToken
                } else if let newCSRFToken = response.allHeaderFields[Header.CSRFToken.name.localizedLowercase] as? String {
                    csrfToken = newCSRFToken
                } else {
                    completionHandler(.failure(.invalidResponse))
                    
                    return
                }
                
                performCall(withMethod: method, parameters: parameters, completionHandler: completionHandler)
                
                return
            }
            
            guard let data = data else {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            guard let parsedResponse = try? JSONDecoder().decode(T.self, from: data) else {
                completionHandler(.failure(.invalidResponse))

                return
            }

            completionHandler(.success(parsedResponse))
        }
        
        task.resume()
    }
    
    func test(completionHandler: @escaping (Bool) -> ()) {
        getTorrents {
            if case Result.success = $0 {
                completionHandler(true)
                
                return
            }
            
            completionHandler(false)
        }
    }
    
    #if os(iOS) || os(macOS)
    
    func addTorrent(_ torrent: LocalTorrent, labels: [String] = [], completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ()) {
        var parameters: Parameters
        
        switch torrent {
        case .magnet(let magnet, _):
            parameters = ["filename": magnet]
            
        case .torrent(let data, _, _):
            parameters = ["metainfo": data.base64EncodedString()]
        }
        
        // Use provided labels or fall back to torrent's labels
        let finalLabels = !labels.isEmpty ? labels : torrent.labels
        if !finalLabels.isEmpty {
            parameters["labels"] = finalLabels
        }
        
        performCall(withMethod: "torrent-add", parameters: parameters) { (result: Result<Transmission.RPCResponse.TorrentAdd, TransmissionError>) in
            switch result {
            case .success(let response):
                guard let torrentAdded = response.arguments?["torrent-added"] else {
                    completionHandler(.failure(.parseError))
                    
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
                    self.getTorrent(id: String(torrentAdded.id), completionHandler: completionHandler)
                }
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    #endif
    
    private func getTorrents(ids: [Int], completionHandler: @escaping (Result<[RemoteTorrent], ServerCommunicationError>) -> ()) {
        let parameters: Parameters
        
        if ids.count != 0 {
            parameters = [
                "fields": Self.TorrentFields,
                "ids": ids
            ]
        } else {
            parameters = ["fields": Self.TorrentFields]
        }
        
        performCall(withMethod: "torrent-get", parameters: parameters) { (result: Result<Transmission.RPCResponse.TorrentGet, TransmissionError>) in
            switch result {
            case .success(let response):
                guard let transmissionTorrents = response.arguments?["torrents"] else {
                    completionHandler(.failure(.parseError))
                    
                    return
                }
                
                if case let Transmission.RPCResponse.Result.error(error) = response.result {
                    completionHandler(.failure(.serverError(error)))
                    
                    return
                }
                
                completionHandler(.success(transmissionTorrents.compactMap { RemoteTorrent(from: $0) }))
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    func getTorrent(id: String, completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ()) {
        getTorrents(ids: [Int(id)].compactMap { $0 }) {
            switch $0 {
            case .success(let torrents):
                guard torrents.count == 1 else {
                    completionHandler(.failure(.parseError))
                    
                    return
                }
                
                completionHandler(.success(torrents[0]))
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    func getTorrents(completionHandler: @escaping (Result<[RemoteTorrent], ServerCommunicationError>) -> ()) {
        getTorrents(ids: [], completionHandler: completionHandler)
    }
    
    private func removeTorrents(byId ids: [String], deletingData: Bool, completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ()) {
        let parameters: Parameters = [
            "ids": ids.map { Int($0) },
            "delete-local-data": deletingData
        ]
        
        performCall(withMethod: "torrent-remove", parameters: parameters) { (result: Result<Transmission.RPCResponse.NoArguments, TransmissionError>) in
            switch result {
            case .success(let response):
                switch response.result {
                case .success:
                    completionHandler(.success(true))
                case .error:
                    completionHandler(.success(false))
                }
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    private func performGenericAction(withMethodName methodName: String, torrentIds: [String], completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ()) {
        let parameters: Parameters = [
            "ids": torrentIds.map { Int($0) }
        ]
        
        performCall(withMethod: methodName, parameters: parameters) { (result: Result<Transmission.RPCResponse.NoArguments, TransmissionError>) in
            switch result {
            case .success(let response):
                switch response.result {
                case .success:
                    completionHandler(.success(true))
                case .error:
                    completionHandler(.success(false))
                }
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    func perform(_ action: RemoteTorrent.Action, on torrent: RemoteTorrent, completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ()) {
        let torrentIds = [torrent.id]
        
        switch action {
        case .pause:
            performGenericAction(withMethodName: "torrent-stop", torrentIds: torrentIds, completionHandler: completionHandler)
            
        case .remove(let deletingData):
            removeTorrents(byId: torrentIds, deletingData: deletingData, completionHandler: completionHandler)
            
        case .start:
            performGenericAction(withMethodName: "torrent-start-now", torrentIds: torrentIds, completionHandler: completionHandler)
        }
    }
}

extension TransmissionConnection: HasSpeedLimitSupport {
    
    func getSpeedLimitConfiguration(completionHandler: @escaping (Result<(down: Double, up: Double), ServerCommunicationError>) -> ()) {
        let parameters: Parameters = [
            "fields": ["speed-limit-up", "speed-limit-down"],
        ]
        
        performCall(withMethod: "session-get", parameters: parameters) { (result: Result<Transmission.RPCResponse.SessionArgumentsNumber, TransmissionError>) in
            switch result {
            case .success(let response):
                guard let responseArguments = response.arguments,
                      let speedLimitDown = responseArguments["speed-limit-down"],
                      let speedLimitUp = responseArguments["speed-limit-up"] else {
                    completionHandler(.failure(.parseError))
                    
                    return
                }
                
                completionHandler(.success((speedLimitDown, speedLimitUp)))
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    func getSpeedLimitState(completionHandler: @escaping (Result<(down: Bool, up: Bool), ServerCommunicationError>) -> ()) {
        let parameters: Parameters = [
            "fields": ["speed-limit-up-enabled", "speed-limit-down-enabled"],
        ]
        
        performCall(withMethod: "session-get", parameters: parameters) { (result: Result<Transmission.RPCResponse.SessionArgumentsBoolean, TransmissionError>) in
            switch result {
            case .success(let response):
                guard let responseArguments = response.arguments,
                      let speedLimitDownEnabled = responseArguments["speed-limit-down-enabled"],
                      let speedLimitUpEnabled = responseArguments["speed-limit-up-enabled"] else {
                    completionHandler(.failure(.parseError))
                    
                    return
                }
                
                completionHandler(.success((speedLimitDownEnabled, speedLimitUpEnabled)))
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
    
    func setSpeedLimitState(_ enabled: (down: Bool, up: Bool), completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ()) {
        let parameters: Parameters = [
            "speed-limit-down-enabled": enabled.down,
            "speed-limit-up-enabled": enabled.up
        ]
        
        performCall(withMethod: "session-set", parameters: parameters) { (result: Result<Transmission.RPCResponse.NoArguments, TransmissionError>) in
            switch result {
            case .success(let response):
                switch response.result {
                case .success:
                    completionHandler(.success(true))
                case .error:
                    completionHandler(.success(false))
                }
                
            case .failure(let error):
                completionHandler(.failure(.serverError(error.localizedDescription)))
            }
        }
    }
}
