//
//  NewServerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 24/08/2020.
//

import SwiftUI

struct NewServerView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var serverRepository: ServerRepository

    @State private var editorModel: ServerEditorModel?

    var body: some View {
        Group {
            if let editorModel {
                ServerEditorForm(
                    model: editorModel,
                    onSaveSuccess: { dismiss() }
                )
            } else {
                ProgressView("Preparing server...")
            }
        }
        .navigationTitle("New Server")
        .task {
            if editorModel == nil {
                editorModel = ServerEditorModel(repository: serverRepository)
            }
        }
    }
}

struct NewServerView_Previews: PreviewProvider {

    static var previews: some View {
        NavigationStack {
            NewServerView()
        }
        .environmentObject(PreviewMockData.serverRepository)
    }
}
