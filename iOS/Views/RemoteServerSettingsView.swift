//
//  RemoteServerSettingsView.swift
//  SeedTruck (iOS)
//
//  Created by Eduardo Almeida on 04/10/2021.
//

import SwiftUI

struct RemoteServerSettingsView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    @ObservedObject var presenter: RemoteServerSettingsPresenter
    
    var leadingNavigationBarItems: some View {
        Button("Close") {
            presentation.wrappedValue.dismiss()
        }
    }
    
    @ViewBuilder
    var innerView: some View {
        VStack {
            if presenter.isLoading {
                LoadingView()
            } else {
                if !presenter.hasServerSupport {
                    Text("No server support.")
                } else if presenter.isErrored {
                    ErrorView(type: .noConnection)
                } else {
                    Form {
                        Section(header: Text("Speed Limit"), footer: Text("To edit these values, please do it in Transmission itself.")) {
                            switch presenter.speedLimitConfiguration {
                            case .notConfigured:
                                Text("Not configured.")
                            case .configured(let down, let up):
                                HStack {
                                    Text("Download")
                                    Spacer()
                                    Text(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: Int(down * 1024)))
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Upload")
                                    Spacer()
                                    Text(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: Int(up * 1024)))
                                        .foregroundColor(.secondary)
                                }
                            case .none:
                                Text("...")
                            }
                        }
                        
                        Section(header: Text("State")) {
                            Toggle("Download Speed Limit", isOn: Binding<Bool>(
                                get: { presenter.speedLimitState!.down },
                                set: { _ in presenter.perform(.toggleDownSpeedLimit) }
                            ))
                            
                            Toggle("Upload Speed Limit", isOn: Binding<Bool>(
                                get: { presenter.speedLimitState!.up },
                                set: { _ in presenter.perform(.toggleUpSpeedLimit) }
                            ))
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            innerView
                .navigationTitle("Server Settings")
                .navigationBarItems(leading: leadingNavigationBarItems)
        }
    }
}

struct RemoteServerSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        RemoteServerSettingsView(presenter: RemoteServerSettingsPresenter(server: PreviewMockData.server))
    }
}
