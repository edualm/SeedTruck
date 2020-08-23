//
//  TransmissionConnection.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

class TransmissionConnection: ServerConnection {
    
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
    
    private let connectionDetails: ConnectionDetails
    private var csrfToken: String?
    
    init(connectionDetails: ConnectionDetails) {
        self.connectionDetails = connectionDetails
    }
    
    private func performCall(withMethod method: String, parameters: Dictionary<String, String>?, completionHandler: @escaping (Result<Transmission.RPCResponse, TransmissionError>) -> ()) {
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
            
            guard let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: .init()) as? [String: Any] else {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            guard let parsedResponse = Transmission.RPCResponse(json: jsonResponse) else {
                completionHandler(.failure(.invalidResponse))
                
                return
            }
            
            completionHandler(.success(parsedResponse))
        }
        
        task.resume()
    }
    
    func addTorrent(_ torrent: LocalTorrent, completionHandler: (Result<RemoteTorrent, ServerCommunicationError>) -> ()) {
        completionHandler(.failure(.notImplemented))
    }
    
    func getTorrents(completionHandler: (Result<[RemoteTorrent], ServerCommunicationError>) -> ()) {
        performCall(withMethod: "torrent-get", parameters: [:]) { result in
            switch result {
            case .success(let response):
                ()
                
            case .failure(let error):
                ()
            }
        }
    }
    
    func removeTorrent(_ torrent: RemoteTorrent, completionHandler: (Result<Bool, ServerCommunicationError>) -> ()) {
        completionHandler(.failure(.notImplemented))
    }
    
    func removeTorrent(byId id: String, completionHandler: (Result<Bool, ServerCommunicationError>) -> ()) {
        completionHandler(.failure(.notImplemented))
    }
}
