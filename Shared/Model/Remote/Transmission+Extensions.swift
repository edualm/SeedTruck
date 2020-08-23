//
//  Transmission+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import Foundation

extension Transmission.RPCResponse.Generic {
    
    init?(json: [String: Any]) {
        guard let result = json["result"] as? String else {
            return nil
        }
        
        if let tag = json["tag"] as? Int {
            self.tag = tag
        } else {
            self.tag = nil
        }
        
        guard result == "success" else {
            self.result = .error(result)
            
            self.arguments = nil
            
            return
        }
        
        self.result = .success
        
        if let arguments = json["arguments"] as? Dictionary<String, Any> {
            self.arguments = arguments
        } else {
            self.arguments = nil
        }
    }
}

extension Transmission.RPCResponse.Result: Codable {
    
    enum Key: CodingKey {
        
        case rawValue
        case associatedValue
    }
    
    enum CodingError: Error {
        
        case unknownValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        
        switch rawValue {
        case "success":
            self = .success
            
        case "error":
            let error = try container.decode(String.self, forKey: .associatedValue)
            self = .error(error)
            
        default:
            throw CodingError.unknownValue
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        
        switch self {
        case .success:
            try container.encode("success", forKey: .rawValue)
            
        case .error(let error):
            try container.encode("error", forKey: .rawValue)
            try container.encode(error, forKey: .associatedValue)
        }
    }
}
