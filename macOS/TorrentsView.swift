//
//  TorrentsView.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

struct TorrentsView: View {
    
    private enum PresentedSheet {
        
        case serverSettings
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    private var managedContextDidSave = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    @State var selectedServer: Server?
    @State var filter: Filter?
    
    @State var filterQuery: String = ""
    
    @State private var presentedSheet: PresentedSheet?
    
    private func reloadData() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
        }
    }
    
    var innerBody: some View {
        let isPresentingModal = Binding<Bool>(
            get: { presentedSheet != nil },
            set: { _ in presentedSheet = nil }
        )
        
        return NavigationView {
            VStack {
                if serverConnections.count > 1 {
                    if let s = selectedServer {
                        Menu(s.name) {
                            ForEach(serverConnections, id: \.self) { server in
                                Button {
                                    selectedServer = server
                                } label: {
                                    Text(server.name)
                                    Image(systemName: "server.rack")
                                }
                            }
                        }.padding([.top, .leading, .trailing])
                    }
                    
                    Spacer()
                }
                
                HStack {
                    if serverConnections.count > 0 {
                        Menu {
                            Button {
                                filter = nil
                            } label: {
                                Text("Show All")
                                Image(systemName: "circle.fill")
                            }
                            
                            Divider()
                            
                            ForEach(filterMenuItems, id: \.self) { item in
                                Button {
                                    item.action()
                                } label: {
                                    Text(item.name)
                                    Image(systemName: item.systemImage)
                                }
                            }
                        } label: {
                            if let f = filter, let item = menuItem(forFilter: f) {
                                Text(item.name)
                                Image(systemName: item.systemImage)
                            } else {
                                Text("Show All")
                                Image(systemName: "circle.fill")
                            }
                        }
                        
                        Button {
                            self.presentedSheet = .serverSettings
                        } label: {
                            Image(systemName: "dial.max")
                        }
                        
                        Button {
                            reloadData()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }.padding(serverConnections.count > 1 ? [.leading, .trailing] : [.top, .leading, .trailing])
                
                TorrentListView(server: $selectedServer, filter: $filter, filterQuery: .constant(""))
                    .navigationTitle(selectedServer?.name ?? "Torrents")
                    .frame(minWidth: 300)
                    .sheet(isPresented: isPresentingModal) {
                        switch presentedSheet {
                        case .serverSettings:
                            if let server = selectedServer {
                                RemoteServerSettingsView(presenter: RemoteServerSettingsPresenter(server: server))
                            } else {
                                EmptyView()
                            }
                        case .none:
                            EmptyView()
                        }
                    }
            }
        }
        .navigationViewStyle(Style.navigationView)
        .onAppear(perform: onAppear)
        .onReceive(managedContextDidSave) { _ in
            selectedServer = serverConnections.first
        }
    }
    
    var body: some View {
        if #available(macOS 12.0, *) {
            innerBody
                .searchable(text: $filterQuery)
        } else {
            innerBody
        }
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
