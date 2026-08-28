//
//  URLProtocolStub.swift
//  Tests iOS
//

import Foundation

final class URLProtocolStub: URLProtocol {

    struct Stub: Sendable {

        let statusCode: Int
        let headers: [String: String]
        let data: Data
        let delay: TimeInterval

        init(
            statusCode: Int = 200,
            headers: [String: String] = [:],
            data: Data = Data(),
            delay: TimeInterval = 0
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.data = data
            self.delay = delay
        }
    }

    typealias Handler = @Sendable (URLRequest, Data?) throws -> Stub

    private final class State: @unchecked Sendable {

        let lock = NSLock()
        var handler: Handler?
        var capturedRequests: [URLRequest] = []
        var capturedRequestBodies: [Data?] = []
    }

    private static let state = State()

    private var deliveryWorkItem: DispatchWorkItem?

    static var requests: [URLRequest] {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.capturedRequests
    }

    static var requestBodies: [Data?] {
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.capturedRequestBodies
    }

    static func setHandler(_ handler: @escaping Handler) {
        state.lock.lock()
        state.handler = handler
        state.capturedRequests = []
        state.capturedRequestBodies = []
        state.lock.unlock()
    }

    static func reset() {
        state.lock.lock()
        state.handler = nil
        state.capturedRequests = []
        state.capturedRequestBodies = []
        state.lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let requestBody = Self.bodyData(from: request)
        Self.state.lock.lock()
        let handler = Self.state.handler
        Self.state.capturedRequests.append(request)
        Self.state.capturedRequestBodies.append(requestBody)
        Self.state.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let stub = try handler(request, requestBody)
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: stub.statusCode,
                    httpVersion: nil,
                    headerFields: stub.headers
                  ) else {
                throw URLError(.badServerResponse)
            }

            let deliveryWorkItem = DispatchWorkItem { [weak self] in
                guard let self, self.deliveryWorkItem?.isCancelled == false else {
                    return
                }

                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: stub.data)
                self.client?.urlProtocolDidFinishLoading(self)
            }
            self.deliveryWorkItem = deliveryWorkItem

            if stub.delay > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay, execute: deliveryWorkItem)
            } else {
                deliveryWorkItem.perform()
            }
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        deliveryWorkItem?.cancel()
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else {
                return nil
            }
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
