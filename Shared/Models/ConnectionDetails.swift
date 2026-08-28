//
//  ConnectionDetails.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/09/2020.
//

import Foundation

struct ConnectionDetails: Equatable, Sendable {

    struct Credentials: Codable, Equatable, Sendable {

        let username: String
        let password: String
    }

    struct CustomHeader: Codable, Equatable, Hashable, Sendable {

        let name: String
        let value: String
    }

    let type: ServerType
    let endpoint: URL
    let credentials: Credentials?
    let customHeaders: [CustomHeader]

    init(
        type: ServerType,
        endpoint: URL,
        credentials: Credentials?,
        customHeaders: [CustomHeader] = []
    ) {
        self.type = type
        self.endpoint = endpoint
        self.credentials = credentials
        self.customHeaders = customHeaders
    }

    func applyCustomHeaders(to request: inout URLRequest) {
        for header in customHeaders {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
    }

    func redirectRequest(from sourceURL: URL, proposedRequest: URLRequest) -> URLRequest {
        guard let destinationURL = proposedRequest.url,
              !Self.haveSameOrigin(sourceURL, destinationURL) else {
            return proposedRequest
        }

        var request = proposedRequest
        let sensitiveHeaderNames = customHeaders.map(\.name) + [
            "Authorization",
            "Cookie",
            "X-Transmission-Session-Id"
        ]
        for name in sensitiveHeaderNames {
            request.setValue(nil, forHTTPHeaderField: name)
        }
        return request
    }

    private static func haveSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let lhsScheme = lhs.scheme?.lowercased(),
              let rhsScheme = rhs.scheme?.lowercased(),
              let lhsHost = lhs.host?.lowercased(),
              let rhsHost = rhs.host?.lowercased() else {
            return false
        }

        return lhsScheme == rhsScheme
            && lhsHost == rhsHost
            && effectivePort(of: lhs, scheme: lhsScheme) == effectivePort(of: rhs, scheme: rhsScheme)
    }

    private static func effectivePort(of url: URL, scheme: String) -> Int? {
        if let port = url.port {
            return port
        }
        switch scheme {
        case "http":
            return 80
        case "https":
            return 443
        default:
            return nil
        }
    }
}

final class CustomHeaderRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {

    private let connectionDetails: ConnectionDetails

    init(connectionDetails: ConnectionDetails) {
        self.connectionDetails = connectionDetails
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let sourceURL = response.url else {
            completionHandler(nil)
            return
        }
        completionHandler(
            connectionDetails.redirectRequest(from: sourceURL, proposedRequest: request)
        )
    }
}
