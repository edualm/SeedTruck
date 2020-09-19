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
    
    private struct MenuItem: Hashable {
        
        let name: String
        let systemImage: String
        let action: () -> ()
        
        static func == (lhs: TorrentsView.MenuItem, rhs: TorrentsView.MenuItem) -> Bool {
            lhs.name == rhs.name
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
        }
    }
    
    private enum PresentedSheet {
        case addMagnet
        case addTorrent(LocalTorrent)
    }
    
    @State var pickerAdapter: DocumentPickerAdapter?
    
    private var addMenuItems: [MenuItem] {
        [
            .init(name: "Magnet Link", systemImage: "link") {
                self.presentedSheet = .addMagnet
            },
            .init(name: "Torrent File", systemImage: "doc") {
                #if !os(macOS)
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
                
                UIApplication.shared.windows.first?.rootViewController?.present(pickerAdapter!.picker, animated: true)
                #endif
            }
        ]
    }
    
    private var filterMenuItems: [MenuItem] {
        [
            .init(name: "Stopped", systemImage: "stop.circle") {
                filter = .stopped
            },
            .init(name: "Downloading", systemImage: "arrow.down.forward.circle") {
                filter = .downloading
            },
            .init(name: "Seeding", systemImage: "arrow.up.forward.circle") {
                filter = .seeding
            },
            .init(name: "Other", systemImage: "questionmark.circle") {
                filter = .other
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
    
    @State private var selectedServer: Server?
    @State private var filter: Filter?
    @State private var showingAlert: AlertIdentifier?
    @State private var presentedSheet: PresentedSheet?
    
    func onAppear() {
        if selectedServer == nil {
            selectedServer = serverConnections.first
        }
    }
    
    var body: some View {
        let isPresentingModal = Binding<Bool>(
            get: { presentedSheet != nil },
            set: { _ in presentedSheet = nil }
        )
        
        var listView = AnyView(TorrentListView(server: $selectedServer, filter: $filter)
            .navigationTitle(selectedServer?.name ?? "Torrents"))
        
        #if !os(macOS)
        
        listView = AnyView(listView.navigationBarItems(leading: serverConnections.count > 1 ? AnyView(Menu {
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
        }) : AnyView(EmptyView()), trailing: serverConnections.count > 0 ? AnyView(HStack {
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
        }) : AnyView(EmptyView())))
        
        #endif
        
        return NavigationView {
            VStack {
                #if os(macOS)
                
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
                    }.padding()
                }
                
                Spacer()
                
                #endif
                
                listView
            }
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
            case .none:
                EmptyView()
            }
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
