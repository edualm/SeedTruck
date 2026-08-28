//
//  SettingsPresenter.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import Foundation

@MainActor
final class SettingsPresenter: ObservableObject {
    
    @Published var showingDeleteAlert = false
    @Published var persistenceError: String?
    @Published private(set) var persistenceErrorIsCleanupWarning = false
    
    var serverUnderModification: Server?
    
    let repository: ServerRepository
    
    enum Action {
        
        case abortDeletion
        case delete(Server)
        case confirmDeletion
    }
    
    init(
        repository: ServerRepository
    ) {
        self.repository = repository
    }
    
    func perform(_ action: Action) {
        switch action {
        case .abortDeletion:
            serverUnderModification = nil
            showingDeleteAlert = false
            
        case .delete(let server):
            persistenceErrorIsCleanupWarning = false
            serverUnderModification = server
            showingDeleteAlert = true
            
        case .confirmDeletion:
            guard let server = serverUnderModification else {
                return
            }

            serverUnderModification = nil
            showingDeleteAlert = false

            do {
                try repository.delete(id: server.id)
            } catch {
                persistenceError = error.localizedDescription
                persistenceErrorIsCleanupWarning = false
            }
        }
    }
}

protocol ServerConnectionTesting: Sendable {

    func checkConnection(using details: ConnectionDetails) async throws
}

struct LiveServerConnectionTester: ServerConnectionTesting {

    private let builder: any ServerConnectionBuilding

    init(builder: any ServerConnectionBuilding = TorrentClientRegistry.live) {
        self.builder = builder
    }

    func checkConnection(using details: ConnectionDetails) async throws {
        let connection = builder.makeConnection(for: details)
        try await connection.checkConnection()
    }
}

enum ServerEditorOperationState: Equatable, Sendable {

    case idle
    case testing
    case saving
    case success(String)
    case failure(String)
}

struct ServerEditorHeader: Identifiable, Equatable, Sendable {

    let id: UUID
    var name: String
    var value: String

    init(id: UUID = UUID(), name: String = "", value: String = "") {
        self.id = id
        self.name = name
        self.value = value
    }

    init(_ header: ConnectionDetails.CustomHeader) {
        self.init(name: header.name, value: header.value)
    }

    var customHeader: ConnectionDetails.CustomHeader {
        .init(name: name, value: value)
    }
}

@MainActor
final class ServerEditorModel: ObservableObject {

    @Published var name: String
    @Published var endpoint: String
    @Published var typeCode: Int
    @Published var username: String
    @Published var password: String
    @Published var customHeaders: [ServerEditorHeader]
    @Published private(set) var operationState: ServerEditorOperationState
    @Published private(set) var credentialLoadError: String?
    @Published private(set) var saveWarning: String?
    @Published private(set) var suggestsLocalNetworkRecovery = false

    @Published private(set) var server: Server?

    private let repository: ServerRepository
    private let connectionTester: any ServerConnectionTesting
    private let clientRegistry: TorrentClientRegistry
    private var operationGeneration = 0

    init(
        repository: ServerRepository,
        server: Server? = nil,
        connectionTester: any ServerConnectionTesting = LiveServerConnectionTester(),
        clientRegistry: TorrentClientRegistry = .live,
        initialOperationState: ServerEditorOperationState? = nil,
        initiallySuggestsLocalNetworkRecovery: Bool = false
    ) {
        self.repository = repository
        self.server = server
        self.connectionTester = connectionTester
        self.clientRegistry = clientRegistry
        saveWarning = nil

        name = server?.name ?? ""
        endpoint = server?.endpoint.absoluteString ?? ""
        typeCode = Int(server?.type ?? 0)
        customHeaders = server?.customHeaders.map(ServerEditorHeader.init) ?? []

        if let server {
            username = server.credentials?.username ?? ""
            password = server.credentials?.password ?? ""
            credentialLoadError = nil
            operationState = .idle
        } else {
            username = ""
            password = ""
            credentialLoadError = nil
            operationState = .idle
        }

        if let initialOperationState {
            operationState = initialOperationState
        }
        suggestsLocalNetworkRecovery = initiallySuggestsLocalNetworkRecovery
    }

    var isBusy: Bool {
        switch operationState {
        case .testing, .saving:
            return true
        case .idle, .success, .failure:
            return false
        }
    }

    var clientDescriptors: [TorrentClientDescriptor] {
        clientRegistry.descriptors
    }

    var selectedClientDescriptor: TorrentClientDescriptor? {
        ServerType(fromCode: typeCode).flatMap(clientRegistry.descriptor(for:))
    }

    var validation: ServerDraftValidation {
        var validation = TemporaryServer.validate(
            name: name,
            endpoint: endpoint,
            typeCode: typeCode,
            username: username,
            password: password,
            customHeaders: customHeaders.map(\.customHeader)
        )

        if validation.nameError == nil {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if repository.servers.contains(where: {
                $0.id != server?.id
                    && $0.name.localizedCaseInsensitiveCompare(normalizedName) == .orderedSame
            }) {
                validation.nameError = ServerPersistenceError.duplicateName.localizedDescription
            }
        }

        if let credentialLoadError {
            validation.credentialsError = "Saved credentials could not be loaded: \(credentialLoadError)"
        }

        return validation
    }

    func fieldsChanged() {
        operationGeneration += 1
        saveWarning = nil
        suggestsLocalNetworkRecovery = false

        switch operationState {
        case .success, .failure, .testing:
            operationState = .idle
        case .idle, .saving:
            break
        }
    }

    func credentialsChanged() {
        credentialLoadError = nil
        fieldsChanged()
    }

    func addCustomHeader() {
        customHeaders.append(ServerEditorHeader())
        fieldsChanged()
    }

    func removeCustomHeader(id: UUID) {
        customHeaders.removeAll { $0.id == id }
        fieldsChanged()
    }

    func retryLoadingCredentials() {
        guard let server, !isBusy else {
            return
        }

        username = server.credentials?.username ?? ""
        password = server.credentials?.password ?? ""
        credentialLoadError = nil
        operationState = .idle
    }

    func testConnection() async {
        guard !isBusy, let draft = validatedDraft() else {
            return
        }

        operationState = .testing
        suggestsLocalNetworkRecovery = false
        operationGeneration += 1
        let generation = operationGeneration

        do {
            try await connectionTester.checkConnection(using: draft.connectionDetails)
            try Task.checkCancellation()
            guard generation == operationGeneration else {
                return
            }
            operationState = .success("Connection established successfully.")
        } catch is CancellationError {
            if generation == operationGeneration {
                operationState = .idle
            }
        } catch {
            if generation == operationGeneration {
                suggestsLocalNetworkRecovery = (error as? ServerCommunicationError)?
                    .suggestsLocalNetworkRecovery == true
                operationState = .failure(error.localizedDescription)
            }
        }
    }

    @discardableResult
    func save() async -> Bool {
        guard !isBusy, let draft = validatedDraft() else {
            return false
        }

        operationState = .saving
        saveWarning = nil
        suggestsLocalNetworkRecovery = false
        operationGeneration += 1
        let generation = operationGeneration
        await Task.yield()

        do {
            if let server {
                self.server = try repository.update(id: server.id, with: draft)
            } else {
                self.server = try repository.insert(draft)
            }

            saveWarning = nil
            if generation == operationGeneration {
                operationState = .success("Server saved successfully.")
            }
            return true
        } catch {
            saveWarning = nil
            if generation == operationGeneration {
                operationState = .failure(error.localizedDescription)
            }
            return false
        }
    }

    private func validatedDraft() -> TemporaryServer? {
        let validation = validation
        guard validation.isValid else {
            let message = validation.nameError
                ?? validation.endpointError
                ?? validation.typeError
                ?? validation.credentialsError
                ?? validation.customHeadersError
                ?? "Review the server fields."
            operationState = .failure(message)
            return nil
        }

        do {
            return try TemporaryServer(
                validatingName: name,
                endpoint: endpoint,
                typeCode: typeCode,
                username: username,
                password: password,
                customHeaders: customHeaders.map(\.customHeader)
            )
        } catch {
            operationState = .failure(error.localizedDescription)
            return nil
        }
    }
}
