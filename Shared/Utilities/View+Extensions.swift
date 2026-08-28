//
//  View+Extensions.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 13/12/2020.
//

import SwiftUI

private struct Center: ViewModifier {
    
    func body(content: Content) -> some View {
        HStack {
            Spacer()
            content
            Spacer()
        }
    }
}

private struct ServerStoreErrorAlert: ViewModifier {

    @EnvironmentObject private var repository: ServerRepository

    func body(content: Content) -> some View {
        content
            .alert(
                "Unable to Save Data",
                isPresented: Binding(
                    get: { repository.errorMessage != nil },
                    set: { if !$0 { repository.errorMessage = nil } }
                )
            ) {
                Button("OK") {
                    repository.errorMessage = nil
                }
            } message: {
                Text(repository.errorMessage ?? "The server store is unavailable.")
            }
    }
}

extension View {
    
    func centered() -> some View {
        self.modifier(Center())
    }

    func serverStoreErrorAlert() -> some View {
        modifier(ServerStoreErrorAlert())
    }
}
