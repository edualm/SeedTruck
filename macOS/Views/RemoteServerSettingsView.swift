//
//  RemoteServerSettingsView.swift
//  SeedTruck (macOS)
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
            HStack {
                Button {
                    presentation.wrappedValue.dismiss()
                } label: {
                    Text("Close")
                }
                
                Spacer()
            }.padding(.bottom)
            
            if presenter.isLoading {
                LoadingView()
            } else {
                if !presenter.hasServerSupport {
                    ErrorView(type: .notSupported)
                } else if presenter.isErrored {
                    ErrorView(type: .noConnection)
                } else {
                    Form {
                        Section(header: Text("Speed Limit").bold().padding(.bottom, 4), footer: Text("To edit these values, please do it in Transmission itself.")) {
                            switch presenter.speedLimitConfiguration {
                            case .notConfigured:
                                Text("Not configured.")
                            case .configured(let down, let up):
                                HStack {
                                    Text("Download")
                                    Spacer()
                                    Text(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: Int(down * 1024)))
                                        .foregroundColor(.secondary)
                                }.padding(.bottom, 4)
                                HStack {
                                    Text("Upload")
                                    Spacer()
                                    Text(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: Int(up * 1024)))
                                        .foregroundColor(.secondary)
                                }.padding(.bottom, 4)
                            case .none:
                                EmptyView()
                            }
                        }
                        
                        Text("")
                            .padding(.bottom)
                        
                        Section(header: Text("State").bold()) {
                            Toggle("Download Speed Limit", isOn: Binding<Bool>(
                                get: { presenter.speedLimitState!.down },
                                set: { _ in presenter.perform(.toggleDownSpeedLimit) }
                            ))
                            .padding(.bottom, 4)
                            
                            Toggle("Upload Speed Limit", isOn: Binding<Bool>(
                                get: { presenter.speedLimitState!.up },
                                set: { _ in presenter.perform(.toggleUpSpeedLimit) }
                            ))
                            .padding(.bottom, 4)
                        }
                    }
                }
            }
        }
    }
    
    var body: some View {
        innerView
            .padding()
            .frame(minWidth: 500)
    }
}

struct RemoteServerSettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        RemoteServerSettingsView(presenter: RemoteServerSettingsPresenter(server: PreviewMockData.server))
    }
}
