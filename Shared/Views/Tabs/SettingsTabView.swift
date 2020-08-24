//
//  SettingsTabView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct SettingsTabView: View {
    
    private enum ConnectionResult {
        case connecting
        
        case success
        case failure
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    @State private var showingNewServer = false
    @State private var connectionResults: [Server: ConnectionResult] = [:]
    
    @ObservedObject private var presenter: SettingsPresenter
    
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
                                
                            }) {
                                Label("Edit", systemImage: "rectangle.and.pencil.and.ellipsis")
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
                    
                    Section {
                        NavigationLink(destination: NewServerView(showing: $showingNewServer), isActive: $showingNewServer) {
                            Text("New Server")
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear(perform: onAppear)
        .onReceive(managedContextDidSave) { _ in
            onAppear()
        }
    }
}

struct SettingsTabView_Previews: PreviewProvider {
    
    static var previews: some View {
        SettingsTabView(presenter: SettingsPresenter(managedObjectContext: MockCoreDataManagedObjectDeleter()))
    }
}
