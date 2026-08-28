//
//  TemporaryServer.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 16/09/2020.
//

import Foundation

enum ServerPersistenceError: Error, Equatable, LocalizedError, Sendable {

    case invalidName
    case invalidEndpoint
    case invalidType
    case incompleteCredentials
    case invalidCustomHeaders(String)
    case duplicateName
    case persistence(String)

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter a server name."
        case .invalidEndpoint:
            return "Enter a valid HTTP or HTTPS server endpoint."
        case .invalidType:
            return "Select a supported server type."
        case .incompleteCredentials:
            return "Enter both a username and password, or leave both empty."
        case .invalidCustomHeaders(let message):
            return message
        case .duplicateName:
            return "A server with this name already exists."
        case .persistence(let message):
            return message
        }
    }
}

struct ServerDraftValidation: Equatable, Sendable {

    var nameError: String?
    var endpointError: String?
    var typeError: String?
    var credentialsError: String?
    var customHeadersError: String?
    var transportWarning: String?

    var isValid: Bool {
        nameError == nil
            && endpointError == nil
            && typeError == nil
            && credentialsError == nil
            && customHeadersError == nil
    }
}

struct TemporaryServer: Sendable {

    let endpoint: URL
    let name: String
    let type: ServerType
    let credentials: ConnectionDetails.Credentials?
    let customHeaders: [ConnectionDetails.CustomHeader]

    init(
        validatingName name: String,
        endpoint endpointString: String,
        typeCode: Int,
        username: String,
        password: String,
        customHeaders: [ConnectionDetails.CustomHeader] = []
    ) throws {
        let validation = Self.validate(
            name: name,
            endpoint: endpointString,
            typeCode: typeCode,
            username: username,
            password: password,
            customHeaders: customHeaders
        )

        if validation.nameError != nil {
            throw ServerPersistenceError.invalidName
        }
        if validation.endpointError != nil {
            throw ServerPersistenceError.invalidEndpoint
        }
        if validation.typeError != nil {
            throw ServerPersistenceError.invalidType
        }
        if validation.credentialsError != nil {
            throw ServerPersistenceError.incompleteCredentials
        }
        if let customHeadersError = validation.customHeadersError {
            throw ServerPersistenceError.invalidCustomHeaders(customHeadersError)
        }

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEndpoint = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endpoint = URL(string: normalizedEndpoint) else {
            throw ServerPersistenceError.invalidEndpoint
        }
        guard let type = ServerType(fromCode: typeCode),
              TorrentClientRegistry.live.descriptor(for: type) != nil else {
            throw ServerPersistenceError.invalidType
        }
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCredentials = !normalizedUsername.isEmpty

        self.endpoint = endpoint
        self.name = normalizedName
        self.type = type
        credentials = hasCredentials
            ? .init(username: normalizedUsername, password: password)
            : nil
        self.customHeaders = try Self.normalizedCustomHeaders(customHeaders)
    }

    static func validate(
        name: String,
        endpoint endpointString: String,
        typeCode: Int,
        username: String,
        password: String,
        customHeaders: [ConnectionDetails.CustomHeader] = []
    ) -> ServerDraftValidation {
        var validation = ServerDraftValidation()

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validation.nameError = "Enter a server name."
        }

        let normalizedEndpoint = endpointString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let endpoint = URL(string: normalizedEndpoint),
           let scheme = endpoint.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           endpoint.host != nil {
            if let type = ServerType(fromCode: typeCode),
               let descriptor = TorrentClientRegistry.live.descriptor(for: type),
               let endpointError = descriptor.endpoint.validationError(for: endpoint) {
                validation.endpointError = endpointError
            } else if scheme == "http" {
                validation.transportWarning = "HTTP is allowed, but authentication details and traffic are not encrypted."
            }
        } else {
            validation.endpointError = "Enter a complete HTTP or HTTPS endpoint."
        }

        if Int16(exactly: typeCode) == nil
            || ServerType(fromCode: typeCode).flatMap({
                TorrentClientRegistry.live.descriptor(for: $0)
            }) == nil {
            validation.typeError = "Select a supported server type."
        }

        let hasUsername = !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPassword = !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasUsername != hasPassword {
            validation.credentialsError = "Enter both a username and password, or leave both empty."
        }

        do {
            _ = try normalizedCustomHeaders(customHeaders)
        } catch let error as ServerPersistenceError {
            validation.customHeadersError = error.localizedDescription
        } catch {
            validation.customHeadersError = "Review the custom headers."
        }

        return validation
    }

    private static func normalizedCustomHeaders(
        _ customHeaders: [ConnectionDetails.CustomHeader]
    ) throws -> [ConnectionDetails.CustomHeader] {
        let validNameCharacters = CharacterSet(
            charactersIn: "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        )
        var seenNames = Set<String>()
        var normalizedHeaders: [ConnectionDetails.CustomHeader] = []

        func containsInvalidControlCharacter(_ value: String) -> Bool {
            value.unicodeScalars.contains { scalar in
                (scalar.value < 0x20 && scalar.value != 0x09) || scalar.value == 0x7F
            }
        }

        for header in customHeaders {
            guard !containsInvalidControlCharacter(header.name),
                  !containsInvalidControlCharacter(header.value) else {
                throw ServerPersistenceError.invalidCustomHeaders(
                    "Header names and values cannot contain control characters."
                )
            }

            let name = header.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = header.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty && value.isEmpty {
                continue
            }
            guard !name.isEmpty, !value.isEmpty else {
                throw ServerPersistenceError.invalidCustomHeaders(
                    "Enter both a name and value for each custom header."
                )
            }
            guard name.unicodeScalars.allSatisfy(validNameCharacters.contains) else {
                throw ServerPersistenceError.invalidCustomHeaders(
                    "Enter a valid HTTP header name."
                )
            }
            guard seenNames.insert(name.lowercased()).inserted else {
                throw ServerPersistenceError.invalidCustomHeaders(
                    "Custom header names must be unique."
                )
            }

            normalizedHeaders.append(.init(name: name, value: value))
        }

        return normalizedHeaders
    }

    var connectionDetails: ConnectionDetails {
        ConnectionDetails(
            type: type,
            endpoint: endpoint,
            credentials: credentials,
            customHeaders: customHeaders
        )
    }

}
