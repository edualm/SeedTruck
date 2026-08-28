//
//  ServerDetailsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ServerEditorForm: View {

    private enum Field: Hashable {
        case name
        case endpoint
        case username
        case password
    }

    @ObservedObject var model: ServerEditorModel
    var remoteSettingsServer: Server?
    var onDeleteRequest: (() -> Void)?
    var onSaveSuccess: (() -> Void)?
    var showsActions = true

    #if os(iOS)
    @Environment(\.openURL) private var openURL
    #endif
    @AccessibilityFocusState private var operationStatusIsFocused: Bool
    @FocusState private var focusedField: Field?
    @State private var touchedFields: Set<Field> = []

    private var validation: ServerDraftValidation {
        model.validation
    }

    private var credentialsErrorField: Field? {
        guard validation.credentialsError != nil else {
            return nil
        }

        return model.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .username
            : .password
    }

    private var showsCredentialsError: Bool {
        model.credentialLoadError != nil
            || touchedFields.contains(.username)
            || touchedFields.contains(.password)
    }

    private var supportsSpeedLimits: Bool {
        remoteSettingsServer?.connection is GlobalSpeedLimitSupporting
    }

    @ViewBuilder
    private func fieldMessage(
        _ message: String?,
        isVisible: Bool = true,
        systemImage: String = "exclamationmark.circle.fill",
        color: Color = .red
    ) -> some View {
        if isVisible, let message {
            Label(message, systemImage: systemImage)
                .labelStyle(CompactLabelStyle())
                .font(.caption)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func customHeaderRow(
        _ header: Binding<ServerEditorHeader>,
        index: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Header \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    model.removeCustomHeader(id: header.wrappedValue.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Header \(index + 1)")
            }

            #if os(iOS)
            TextField("Header Name", text: header.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("server-editor-header-name-\(index)")

            SecureField("Header Value", text: header.value)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("server-editor-header-value-\(index)")
            #else
            TextField("Header Name", text: header.name, prompt: Text("X-Header-Name"))
                .autocorrectionDisabled()
                .accessibilityIdentifier("server-editor-header-name-\(index)")

            SecureField("Header Value", text: header.value, prompt: Text("Secret Value"))
                .autocorrectionDisabled()
                .accessibilityIdentifier("server-editor-header-value-\(index)")
            #endif
        }
    }

    private var customHeadersDisclosure: some View {
        DisclosureGroup("Custom Headers (Optional)") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach($model.customHeaders) { $header in
                    customHeaderRow(
                        $header,
                        index: model.customHeaders.firstIndex(where: { $0.id == header.id }) ?? 0
                    )
                }

                Button {
                    model.addCustomHeader()
                } label: {
                    Label("Add Header", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server-editor-add-header")

                fieldMessage(validation.customHeadersError)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
        .accessibilityIdentifier("server-editor-custom-headers")
    }

    @ViewBuilder
    private var operationStatus: some View {
        switch model.operationState {
        case .idle:
            Label("Ready", systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
        case .testing:
            HStack {
                ProgressView()
                    .accessibilityHidden(true)
                Text("Testing connection...")
            }
            .accessibilityElement(children: .combine)
        case .saving:
            HStack {
                ProgressView()
                    .accessibilityHidden(true)
                Text("Saving server...")
            }
            .accessibilityElement(children: .combine)
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)

                if model.suggestsLocalNetworkRecovery {
                    #if os(iOS)
                    Button("Open App Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    #elseif os(macOS)
                    Text("Review System Settings > Privacy & Security > Local Network before retrying.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif
                }
            }
        }
    }

    private func testConnection() {
        Task {
            await model.testConnection()
        }
    }

    private func save() {
        Task {
            if await model.save() {
                onSaveSuccess?()
            }
        }
    }

    #if os(iOS)
    private var iOSBody: some View {
        Form {
            if let remoteSettingsServer, supportsSpeedLimits {
                Section {
                    NavigationLink {
                        RemoteServerSettingsView(
                            presenter: RemoteServerSettingsPresenter(server: remoteSettingsServer)
                        )
                    } label: {
                        Label(
                            "Global Speed Limits",
                            systemImage: "gauge.with.dots.needle.67percent"
                        )
                    }
                }
            }

            Section("Server") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Name", text: $model.name)
                        .focused($focusedField, equals: .name)
                        .help(Text(verbatim: "A name used to identify this torrent client."))
                        .accessibilityIdentifier("server-editor-name")
                        .accessibilityHint(
                            validation.nameError ?? "A name used to identify this torrent client"
                        )
                    fieldMessage(
                        validation.nameError,
                        isVisible: touchedFields.contains(.name)
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Picker("Type", selection: $model.typeCode) {
                        ForEach(model.clientDescriptors) { descriptor in
                            Text(descriptor.displayName).tag(descriptor.id.code)
                        }
                    }
                    .accessibilityIdentifier("server-editor-type")
                    .accessibilityHint(validation.typeError ?? "Select the server software")
                    fieldMessage(validation.typeError)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Endpoint", text: $model.endpoint)
                        .focused($focusedField, equals: .endpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .help(Text(verbatim: model.selectedClientDescriptor?.endpoint.help ?? "Enter the torrent client endpoint."))
                        .accessibilityIdentifier("server-editor-endpoint")
                        .accessibilityHint(
                            validation.endpointError
                                ?? model.selectedClientDescriptor?.endpoint.help
                                ?? "Enter the torrent client endpoint"
                        )
                    fieldMessage(
                        validation.endpointError,
                        isVisible: touchedFields.contains(.endpoint)
                    )
                    if let descriptor = model.selectedClientDescriptor {
                        Text("Example: \(descriptor.endpoint.example)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    fieldMessage(
                        validation.transportWarning,
                        isVisible: touchedFields.contains(.endpoint),
                        systemImage: "lock.open.trianglebadge.exclamationmark",
                        color: .orange
                    )
                }
            }
            .disabled(model.isBusy)

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Username", text: $model.username)
                        .focused($focusedField, equals: .username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .help(Text(verbatim: "Leave blank when the server does not require authentication."))
                        .accessibilityHint(
                            validation.credentialsError
                                ?? "Leave blank when the server does not require authentication"
                        )
                    fieldMessage(
                        validation.credentialsError,
                        isVisible: showsCredentialsError && credentialsErrorField == .username
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    SecureField("Password", text: $model.password)
                        .focused($focusedField, equals: .password)
                        .help(Text(verbatim: "Leave blank when the server does not require authentication."))
                        .accessibilityHint(
                            validation.credentialsError
                                ?? "Leave blank when the server does not require authentication"
                        )
                    fieldMessage(
                        validation.credentialsError,
                        isVisible: showsCredentialsError && credentialsErrorField == .password
                    )
                }

                if model.credentialLoadError != nil {
                    Button("Retry Loading Saved Credentials") {
                        model.retryLoadingCredentials()
                    }
                }
            } header: {
                Text("Authentication")
            } footer: {
                Text(
                    model.selectedClientDescriptor?.authenticationHelp
                        ?? "Leave both fields empty for servers that do not require authentication."
                )
            }
            .disabled(model.isBusy)

            Section {
                customHeadersDisclosure
            } footer: {
                Text("Add headers required by a reverse proxy or other authentication layer. Values are stored securely with this server.")
            }
            .disabled(model.isBusy)

            if showsActions {
                Section("Connection") {
                    Button(action: testConnection) {
                        Label("Test Connection", systemImage: "bolt.horizontal.circle")
                    }
                    .disabled(model.isBusy || !validation.isValid)

                    if model.operationState != .idle {
                        operationStatus
                            .accessibilityFocused($operationStatusIsFocused)
                    }
                }
            }
        }
        .toolbar {
            if showsActions {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.server != nil, let onDeleteRequest {
                        Button(role: .destructive, action: onDeleteRequest) {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete Server")
                    }

                    Button(action: save) {
                        Image(systemName: "checkmark")
                    }
                        .disabled(model.isBusy || !validation.isValid)
                        .accessibilityLabel(model.server == nil ? "Add Server" : "Save Server")
                        .accessibilityIdentifier("server-editor-save")
                }
            }
        }
    }
    #endif

    #if os(macOS)
    private var macOSBody: some View {
        VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Server")
                        .font(.headline)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow(alignment: .top) {
                            Text("Name")
                                .frame(width: 88, alignment: .trailing)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 5) {
                                TextField("", text: $model.name)
                                    .focused($focusedField, equals: .name)
                                    .accessibilityLabel("Name")
                                    .accessibilityIdentifier("server-editor-name")
                                    .accessibilityHint(
                                        validation.nameError
                                            ?? "A name used to identify this torrent client"
                                    )
                                fieldMessage(
                                    validation.nameError,
                                    isVisible: touchedFields.contains(.name)
                                )
                            }
                        }

                        GridRow(alignment: .top) {
                            Text("Type")
                                .frame(width: 88, alignment: .trailing)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 5) {
                                Picker("", selection: $model.typeCode) {
                                    ForEach(model.clientDescriptors) { descriptor in
                                        Text(descriptor.displayName).tag(descriptor.id.code)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 180, alignment: .leading)
                                .accessibilityLabel("Type")
                                .accessibilityIdentifier("server-editor-type")
                                .accessibilityHint(validation.typeError ?? "Select the server software")
                                fieldMessage(validation.typeError)
                            }
                        }

                        GridRow(alignment: .top) {
                            Text("Endpoint")
                                .frame(width: 88, alignment: .trailing)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 5) {
                                TextField("", text: $model.endpoint)
                                    .focused($focusedField, equals: .endpoint)
                                    .accessibilityLabel("Endpoint")
                                    .accessibilityIdentifier("server-editor-endpoint")
                                    .accessibilityHint(
                                        validation.endpointError
                                            ?? model.selectedClientDescriptor?.endpoint.help
                                            ?? "Enter the torrent client endpoint"
                                    )
                                fieldMessage(
                                    validation.endpointError,
                                    isVisible: touchedFields.contains(.endpoint)
                                )
                                if let descriptor = model.selectedClientDescriptor {
                                    Text("Example: \(descriptor.endpoint.example)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                fieldMessage(
                                    validation.transportWarning,
                                    isVisible: touchedFields.contains(.endpoint),
                                    systemImage: "lock.open.trianglebadge.exclamationmark",
                                    color: .orange
                                )
                            }
                        }
                    }
                }
                .disabled(model.isBusy)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Authentication")
                        .font(.headline)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        GridRow(alignment: .top) {
                            Text("Username")
                                .frame(width: 88, alignment: .trailing)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 5) {
                                TextField("", text: $model.username)
                                    .focused($focusedField, equals: .username)
                                    .accessibilityLabel("Username")
                                fieldMessage(
                                    validation.credentialsError,
                                    isVisible: showsCredentialsError && credentialsErrorField == .username
                                )
                            }
                        }

                        GridRow(alignment: .top) {
                            Text("Password")
                                .frame(width: 88, alignment: .trailing)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 5) {
                                SecureField("", text: $model.password)
                                    .focused($focusedField, equals: .password)
                                    .accessibilityLabel("Password")
                                fieldMessage(
                                    validation.credentialsError,
                                    isVisible: showsCredentialsError && credentialsErrorField == .password
                                )
                            }
                        }
                    }

                    Text(
                        model.selectedClientDescriptor?.authenticationHelp
                            ?? "Leave both fields empty for servers that do not require authentication."
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 100)

                    if model.credentialLoadError != nil {
                        Button("Retry Loading Saved Credentials") {
                            model.retryLoadingCredentials()
                        }
                        .padding(.leading, 100)
                    }
                }
                .disabled(model.isBusy)

                VStack(alignment: .leading, spacing: 12) {
                    customHeadersDisclosure

                    Text("Add headers required by a reverse proxy or other authentication layer. Values are stored securely with this server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(model.isBusy)

                if model.operationState != .idle {
                    Divider()
                    operationStatus
                        .padding(.leading, 100)
                        .accessibilityFocused($operationStatusIsFocused)
                }

                if showsActions {
                    HStack {
                        Button("Test Connection", action: testConnection)
                            .disabled(model.isBusy || !validation.isValid)

                        Spacer()

                        Button(model.server == nil ? "Add" : "Save", action: save)
                            .keyboardShortcut(.defaultAction)
                            .disabled(model.isBusy || !validation.isValid)
                            .accessibilityIdentifier("server-editor-save")
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .controlSize(.regular)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    #endif

    #if os(tvOS)
    private var tvOSBody: some View {
        Form {
            Section("Server") {
                TextField("Name", text: $model.name)
                    .accessibilityIdentifier("server-editor-name")
                fieldMessage(validation.nameError)

                Picker("Type", selection: $model.typeCode) {
                    ForEach(model.clientDescriptors) { descriptor in
                        Text(descriptor.displayName).tag(descriptor.id.code)
                    }
                }
                .accessibilityIdentifier("server-editor-type")
                fieldMessage(validation.typeError)

                TextField("Endpoint", text: $model.endpoint)
                    .accessibilityIdentifier("server-editor-endpoint")
                fieldMessage(validation.endpointError)
                if let descriptor = model.selectedClientDescriptor {
                    Text("Example: \(descriptor.endpoint.example)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                fieldMessage(
                    validation.transportWarning,
                    systemImage: "lock.open.trianglebadge.exclamationmark",
                    color: .orange
                )
            }
            .disabled(model.isBusy)

            Section("Authentication") {
                TextField("Username", text: $model.username)
                SecureField("Password", text: $model.password)
                fieldMessage(validation.credentialsError)

                if model.credentialLoadError != nil {
                    Button("Retry Loading Saved Credentials") {
                        model.retryLoadingCredentials()
                    }
                }

                Text(
                    model.selectedClientDescriptor?.authenticationHelp
                        ?? "Leave both fields empty for servers that do not require authentication."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(model.isBusy)

            Section {
                customHeadersDisclosure
            }
            .disabled(model.isBusy)

            Section("Status") {
                operationStatus
            }
            .accessibilityFocused($operationStatusIsFocused)

            if showsActions {
                Section {
                    Button(action: testConnection) {
                        Label("Test Connection", systemImage: "bolt.horizontal.circle")
                    }
                    .disabled(model.isBusy || !validation.isValid)

                    Button(action: save) {
                        Label("Save", systemImage: "checkmark.circle")
                    }
                    .disabled(model.isBusy || !validation.isValid)
                }
            }
        }
    }
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            iOSBody
            #elseif os(macOS)
            macOSBody
            #elseif os(tvOS)
            tvOSBody
            #endif
        }
        .onChange(of: model.name) { _, _ in model.fieldsChanged() }
        .onChange(of: model.endpoint) { _, _ in model.fieldsChanged() }
        .onChange(of: model.typeCode) { _, _ in model.fieldsChanged() }
        .onChange(of: model.username) { _, _ in model.credentialsChanged() }
        .onChange(of: model.password) { _, _ in model.credentialsChanged() }
        .onChange(of: model.customHeaders) { _, _ in model.fieldsChanged() }
        .onChange(of: focusedField) { previousField, currentField in
            if let previousField, previousField != currentField {
                touchedFields.insert(previousField)
            }
        }
        .onChange(of: model.operationState) { _, state in
            switch state {
            case .success, .failure:
                operationStatusIsFocused = true
            case .idle, .testing, .saving:
                operationStatusIsFocused = false
            }
        }
        .onAppear {
            switch model.operationState {
            case .success, .failure:
                operationStatusIsFocused = true
            case .idle, .testing, .saving:
                break
            }
        }
    }
}

struct ServerDetailsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var repository: ServerRepository

    @State private var editorModel: ServerEditorModel?
    @State private var showingDeleteAlert = false
    @State private var deletionError: String?

    private let serverName: String
    private let serverID: UUID

    private var server: Server? {
        repository.server(id: serverID)
    }

    init(serverID: UUID, serverName: String) {
        self.serverID = serverID
        self.serverName = serverName
    }

    private func deleteServer() {
        guard let server else {
            dismiss()
            return
        }

        do {
            try repository.delete(id: server.id)
        } catch {
            deletionError = error.localizedDescription
            return
        }

        editorModel = nil
        showingDeleteAlert = false

        dismiss()
    }

    var body: some View {
        Group {
            if let server, let editorModel {
                ServerEditorForm(
                    model: editorModel,
                    remoteSettingsServer: server,
                    onDeleteRequest: { showingDeleteAlert = true },
                    onSaveSuccess: { dismiss() }
                )
            } else if server != nil {
                ProgressView("Loading server...")
            } else {
                ContentUnavailableView("Server Unavailable", systemImage: "server.rack")
            }
        }
        .navigationTitle(serverName)
        .task {
            if editorModel == nil, let server {
                editorModel = ServerEditorModel(
                    repository: repository,
                    server: server
                )
            }
        }
        .alert("Delete Server?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive, action: deleteServer)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \"\(serverName)\" and its saved credentials.")
        }
        .alert(
            "Unable to Delete Server",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("OK") { deletionError = nil }
        } message: {
            Text(deletionError ?? "The server could not be deleted.")
        }
    }
}

struct ServerDetailsView_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            if let server = PreviewMockData.settingsServer {
                NavigationStack {
                    ServerDetailsView(serverID: server.id, serverName: server.name)
                }
                .environmentObject(PreviewMockData.serverRepository)
            } else {
                ContentUnavailableView("Preview Unavailable", systemImage: "server.rack")
            }

            ServerEditorFormStatePreview(
                state: .failure(
                    ServerCommunicationError.connectivity(.localNetworkUnavailable).localizedDescription
                ),
                suggestsLocalNetworkRecovery: true
            )
            .preferredColorScheme(.dark)
            .previewDisplayName("Local Network Failure - Dark")

            ServerEditorFormStatePreview(state: .testing)
                .environment(\.dynamicTypeSize, .accessibility3)
                .previewDisplayName("Testing - Accessibility Text")
        }
    }
}

private struct ServerEditorFormStatePreview: View {

    @StateObject private var model: ServerEditorModel

    init(
        state: ServerEditorOperationState,
        suggestsLocalNetworkRecovery: Bool = false
    ) {
        let model = ServerEditorModel(
            repository: PreviewMockData.serverRepository,
            initialOperationState: state,
            initiallySuggestsLocalNetworkRecovery: suggestsLocalNetworkRecovery
        )
        model.name = "Living Room Seedbox With A Long Descriptive Name"
        model.endpoint = "http://seedbox-with-a-long-hostname.local:9091/transmission/rpc"
        self._model = StateObject(wrappedValue: model)
    }

    var body: some View {
        ServerEditorForm(model: model)
    }
}
