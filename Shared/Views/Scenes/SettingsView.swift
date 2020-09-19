//
//  SettingsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct SettingsView: View {
    
    private enum ConnectionResult {
        
        case connecting
        
        case success
        case failure
    }
    
    private struct AlertData: Identifiable {
        
        var id: String {
            return title + message
        }
        
        let title: String
        let message: String
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var showingAlert: AlertData?
    @State private var showingNewServer = false
    @State private var connectionResults: [Server: ConnectionResult] = [:]
    
    @ObservedObject private var presenter: SettingsPresenter
    
    @EnvironmentObject private var sharedBucket: SharedBucket
    
    private var managedContextDidSave = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    init(presenter: SettingsPresenter) {
        self.presenter = presenter
    }
    
    func onAppear() {
        connectionResults = serverConnections.reduce(into: [Server: ConnectionResult]()) {
            $0[$1] = .connecting
        }
        
        serverConnections.forEach { server in
            server.connection.test { success in
                DispatchQueue.main.async {
                    connectionResults[server] = success ? .success : .failure
                }
            }
        }
    }
    
    var body: some View {
        let showingDeleteAlertBinding = Binding<Bool>(
            get: { self.presenter.showingDeleteAlert },
            set: { _ in }
        )
        
        let newServerLink = NavigationLink(destination: NewServerView()) {
            Text("New Server")
        }
        
        NavigationView {
            VStack {
                List {
                    ForEach(serverConnections) { server in
                        Section(header: Text(server.name)) {
                            switch connectionResults[server] {
                            case .connecting:
                                Label("Testing...", systemImage: "bolt.horizontal.circle")
                                    .foregroundColor(.gray)
                                
                            case .success:
                                Label("Connection Successful!", systemImage: "checkmark.circle")
                                    .foregroundColor(.green)
                                
                            case .failure:
                                Label("Connection Failed!", systemImage: "xmark.circle")
                                    .foregroundColor(.red)
                                
                            case .none:
                                EmptyView()
                            }
                            Button(action: {
                                self.presenter.perform(.delete(server))
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }.alert(isPresented: showingDeleteAlertBinding) {
                                Alert(title: Text("Are you sure you want to delete \"\(presenter.serverUnderModification?.name ?? "Unknown")\"?"),
                                      message: nil,
                                      primaryButton: .destructive(Text("Delete")) {
                                        self.presenter.perform(.confirmDeletion)
                                      },
                                      secondaryButton: .cancel() {
                                        self.presenter.perform(.abortDeletion)
                                      })
                            }
                        }
                    }
                    
                    #if os(macOS)
                    Section(header: Text("New...")) {
                        newServerLink
                    }
                    #else
                    Section {
                        newServerLink
                    }
                    #endif
                    
                    if let dataTransferManager = sharedBucket.dataTransferManager {
                        Button(action: {
                            dataTransferManager.sendUpdateToWatch {
                                switch $0 {
                                case .success:
                                    showingAlert = .init(title: "Success!", message: "Successfully synced servers with your Apple Watch.")
                                case .failure(let error):
                                    showingAlert = .init(title: "Error!", message: error.localizedDescription)
                                }
                            }
                        }) {
                            Label("Force Sync to Apple Watch", systemImage: "applewatch.radiowaves.left.and.right")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .listStyle(Style.list)
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(Style.navigationView)
        .onAppear(perform: onAppear)
        .onReceive(managedContextDidSave) { _ in
            onAppear()
        }
        .alert(item: $showingAlert) {
            Alert(title: Text($0.title),
                  message: Text($0.message),
                  dismissButton: .default(Text("Ok")))
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    
    static var previews: some View {
        SettingsView(presenter: SettingsPresenter(managedObjectContext: MockCoreDataManagedObjectDeleter()))
    }
}
