//
//  TorrentsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentsView: View {
    
    private struct AlertIdentifier: Identifiable {
        
        enum Choice {
            
            case addTorrentError
        }
        
        var id: Choice
    }
    
    private enum PresentedSheet {
        
        case addMagnet
        case addTorrent(LocalTorrent)
        case serverSettings
    }
    
    @State var pickerAdapter: DocumentPickerAdapter?
    
    private var addMenuItems: [MenuItem] {
        [
            .init(name: "Magnet Link", systemImage: "link") {
                self.presentedSheet = .addMagnet
            },
            .init(name: "Torrent File", systemImage: "doc") {
                self.pickerAdapter = DocumentPickerAdapter(
                    torrentPickerWithOnPick: { url in
                        guard url.lastPathComponent.split(separator: ".").last == "torrent" else {
                            self.showingAlert = .init(id: .addTorrentError)
                            
                            return
                        }
                        
                        guard let torrent = LocalTorrent(url: url) else {
                            self.showingAlert = .init(id: .addTorrentError)
                            
                            return
                        }
                        
                        self.presentedSheet = .addTorrent(torrent)
                    },
                    onDismiss: {}
                )
                
                UIApplication
                    .shared
                    .connectedScenes
                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                    .last?
                    .rootViewController?
                    .present(pickerAdapter!.picker, animated: true)
            }
        ]
    }
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) var serverConnections: FetchedResults<Server>
    
    private var managedContextDidSave = NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
    
    @State private var showingAlert: AlertIdentifier?
    @State private var presentedSheet: PresentedSheet?
    
    @State var filter: Filter?
    @State var selectedServer: Server?
    @State var selectedTorrentId: String?
    
    @State var filterQuery: String = ""
    
    var leadingNavigationBarItems: some View {
        Group {
            if serverConnections.count > 1 {
                Menu {
                    ForEach(serverConnections, id: \.self) { server in
                        Button {
                            selectedServer = server
                        } label: {
                            Text(server.name)
                            Image(systemName: "server.rack")
                        }
                    }
                } label: {
                    Image(systemName: "text.justify")
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var trailingNavigationBarItems: some View {
        Group {
            if serverConnections.count > 0 {
                HStack {
                    Button {
                        self.presentedSheet = .serverSettings
                    } label: {
                        Image(systemName: "dial.max")
                    }
                    
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
                        Image(systemName: filter != nil ? "tag.fill" : "tag")
                    }.padding(.trailing, 5)
                    
                    Menu {
                        ForEach(addMenuItems, id: \.self) { item in
                            Button {
                                item.action()
                            } label: {
                                Text(item.name)
                                Image(systemName: item.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "link.badge.plus")
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    var body: some View {
        let isPresentingModal = Binding<Bool>(
            get: { presentedSheet != nil },
            set: { _ in presentedSheet = nil }
        )
        
        return NavigationView {
            TorrentsViewContent(
                selectedServer: $selectedServer,
                filter: $filter,
                filterQuery: $filterQuery,
                selectedTorrentId: $selectedTorrentId,
                leadingNavigationBarItems: leadingNavigationBarItems,
                trailingNavigationBarItems: trailingNavigationBarItems
            )
        }
        .navigationViewStyle(Style.navigationView)
        .onAppear(perform: onAppear)
        .onReceive(managedContextDidSave) { _ in
            selectedServer = serverConnections.first
        }
        .alert(item: $showingAlert) {
            switch $0.id {
            case .addTorrentError:
                return Alert(title: Text("Error!"),
                             message: Text("An error has occurred while adding the requested torrent."),
                             dismissButton: .default(Text("Ok")))
                
            }
        }
        .sheet(isPresented: isPresentingModal) {
            switch presentedSheet {
            case .addMagnet:
                AddMagnetView(server: $selectedServer)
            case .addTorrent(let torrent):
                TorrentHandlerNavigationView(torrent: torrent, server: selectedServer)
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

private struct TorrentsViewContent<LeadingItems: View, TrailingItems: View>: View {
    
    @Binding var selectedServer: Server?
    @Binding var filter: Filter?
    @Binding var filterQuery: String
    @Binding var selectedTorrentId: String?
    
    let leadingNavigationBarItems: LeadingItems
    let trailingNavigationBarItems: TrailingItems
    
    var body: some View {
        TorrentListView(server: $selectedServer, filter: $filter, filterQuery: $filterQuery, selectedTorrentId: $selectedTorrentId)
            .navigationTitle(filterQuery.isEmpty ? (selectedServer?.name ?? "Torrents") : "")
            .navigationBarItems(
                leading: leadingNavigationBarItems,
                trailing: trailingNavigationBarItems
            )
            .searchable(text: $filterQuery)
            .animation(.none, value: filterQuery)
    }
}

struct TorrentsView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            TorrentsView()
        }
    }
}
