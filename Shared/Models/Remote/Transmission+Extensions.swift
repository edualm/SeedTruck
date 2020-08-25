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
    
    enum CodingError: Error {
        
        case unknownValue
    }
    
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        
        switch value {
        case "success":
            self = .success
            
        default:
            self = .error(value)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .success:
            try container.encode("success")
            
        case .error(let error):
            try container.encode(error)
        }
    }
}

extension Transmission.RPCResponse.Result: Equatable {
    
    static func ==(rhs: Transmission.RPCResponse.Result, lhs: Transmission.RPCResponse.Result) -> Bool {
        switch (rhs, lhs) {
        case (.success, .success):
            return true
            
        case (.success, .error), (.error, .success):
            return false
            
        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError
        }
    }
}
