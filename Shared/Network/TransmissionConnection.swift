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
    
    static private let TorrentFields = ["id", "name", "percentDone", "status", "sizeWhenDone", "peersConnected", "rateUpload", "peersSendingToUs", "peersGettingFromUs", "rateDownload"]
    
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
        
        let task = URLSession.shared.dataTask(with: urlRequest) { [self] data, response, error in
            guard error == nil, let response = response as? HTTPURLResponse else {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            if response.statusCode == 403 || response.statusCode == 500 {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            guard response.statusCode != 409 else {
                guard let newCSRFToken = response.allHeaderFields[Header.CSRFToken.name] as? String else {
                    completionHandler(.failure(.invalidResponse))
                    
                    return
                }
                
                csrfToken = newCSRFToken
                
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
    
    func addTorrent(_ torrent: LocalTorrent, completionHandler: @escaping (Result<RemoteTorrent, ServerCommunicationError>) -> ()) {
        let parameters: Parameters
        
        switch torrent {
        case .magnet(let magnet):
            parameters = ["filename": magnet]
            
        case .torrent(let torrent):
            parameters = ["metainfo": torrent.base64EncodedString()]
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
    
    func removeTorrent(_ torrent: RemoteTorrent, deletingData: Bool, completionHandler: @escaping (Result<Bool, ServerCommunicationError>) -> ()) {
        removeTorrents(byId: [torrent.id], deletingData: deletingData, completionHandler: completionHandler)
    }
}
