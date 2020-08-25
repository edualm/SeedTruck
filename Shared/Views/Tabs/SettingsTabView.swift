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
    
    @ObservedObject private var actionHandler: SettingsActionHandler
    
    private var managedContextDidSave = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    init(actionHandler: SettingsActionHandler) {
        self.actionHandler = actionHandler
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
    
    #if os(watchOS) || os(tvOS)
    static private let listStyle = DefaultListStyle()
    #else
    static private let listStyle = InsetGroupedListStyle()
    #endif
    
    var body: some View {
        let showingDeleteAlertBinding = Binding<Bool>(
            get: { self.actionHandler.showingDeleteAlert },
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
                                self.actionHandler.perform(.delete(server))
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }.alert(isPresented: showingDeleteAlertBinding) {
                                Alert(title: Text("Are you sure you want to delete \"\(actionHandler.serverUnderModification?.name ?? "Unknown")\"?"),
                                      message: nil,
                                      primaryButton: .destructive(Text("Delete")) {
                                        self.actionHandler.perform(.confirmDeletion)
                                      },
                                      secondaryButton: .cancel() {
                                        self.actionHandler.perform(.abortDeletion)
                                      })
                            }
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: NewServerView()) {
                            Text("New Server")
                        }
                    }
                }
                .listStyle(Self.listStyle)
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
        SettingsTabView(actionHandler: SettingsActionHandler(managedObjectContext: MockCoreDataManagedObjectDeleter()))
    }
}
