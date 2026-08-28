//
//  NewServerView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct ServerEditorSheet: View {

    let server: Server?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ServerEditorModel
    @State private var saveInProgress = false

    private var title: String {
        server == nil ? "Add Server" : "Edit Server"
    }

    private var saveTitle: String {
        server == nil ? "Add" : "Save"
    }

    init(server: Server?, repository: ServerRepository) {
        self.server = server
        self._model = StateObject(
            wrappedValue: ServerEditorModel(
                repository: repository,
                server: server
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    ServerEditorForm(
                        model: model,
                        remoteSettingsServer: server,
                        showsActions: false
                    )
                }

                Divider()

                HStack {
                    Button("Test Connection") {
                        Task {
                            await model.testConnection()
                        }
                    }
                    .disabled(saveInProgress || model.isBusy || !model.validation.isValid)

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .disabled(saveInProgress)

                    Button(saveTitle) {
                        saveInProgress = true
                        Task {
                            let didSave = await model.save()
                            saveInProgress = false

                            if didSave, model.saveWarning == nil {
                                dismiss()
                            }
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(saveInProgress || model.isBusy || !model.validation.isValid)
                    .accessibilityIdentifier("server-editor-save")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle(title)
        }
        .frame(width: 520, height: 620)
        .interactiveDismissDisabled(saveInProgress)
        .accessibilityIdentifier("server-editor-sheet")
    }
}

struct ServerEditorSheet_Previews: PreviewProvider {

    static var previews: some View {
        Group {
            ServerEditorSheet(
                server: nil,
                repository: PreviewMockData.serverRepository
            )

            if let server = PreviewMockData.settingsServer {
                ServerEditorSheet(
                    server: server,
                    repository: PreviewMockData.serverRepository
                )
            }
        }
    }
}
