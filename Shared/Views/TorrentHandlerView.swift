//
//  TorrentHandlerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct TorrentHandlerView: View {
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    @State var errorMessage: String? = nil
    @State var selectedServers: [Server] = []
    
    @Binding var presentation: PresentationMode
    
    let torrent: LocalTorrent
    let server: Server?
    
    func startDownload() {
        var remaining = selectedServers.count
        var errors: [(Server, Error)] = []
        
        selectedServers.forEach { server in
            server.connection.addTorrent(torrent) {
                switch $0 {
                case .success:
                    ()
                    
                case .failure(let error):
                    errors.append((server, error))
                }
                
                remaining = remaining - 1
                
                if remaining == 0 {
                    if errors.count == 0 {
                        presentation.dismiss()
                    } else {
                        errorMessage = "An error has occurred while adding the torrent to the following servers:\n\n" +
                            "\(errors.map { "\"\($0.0.name)\": \($0.1.localizedDescription)\n" })\n" +
                            "Please look at the inserted data and try again."
                    }
                }
            }
        }
    }
    
    var body: some View {
        let showingError = Binding<Bool>(
            get: { errorMessage != nil },
            set: {
                if $0 == false {
                    errorMessage = nil
                }
            }
        )
        
        let form = Form {
            Section(header: Text("Torrent Metadata")) {
                if let name = torrent.name {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(name)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let size = torrent.size {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text(ByteCountFormatter.humanReadableFileSize(bytes: size))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let files = torrent.files {
                    HStack {
                        Text("Files")
                        Spacer()
                        Text("\(files.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                if let isPrivate = torrent.isPrivate {
                    HStack {
                        Text("Private")
                        Spacer()
                        Text(isPrivate ? "Yes" : "No")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if server == nil {
                if serverConnections.count > 0 {
                    Section(header: Text("Server(s)")) {
                        ForEach(0 ..< serverConnections.count) { index in
                            Button(action: {
                                let server = serverConnections[index]
                                
                                if selectedServers.contains(server) {
                                    selectedServers.removeAll { $0 == server }
                                } else {
                                    selectedServers.append(server)
                                }
                            }) {
                                HStack {
                                    Text(serverConnections[index].name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedServers.contains(serverConnections[index]) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    GroupBox(label: Label("Oops!", systemImage: "exclamationmark.triangle")) {
                        HStack {
                            Text("You must first configure at least one server in the app in order to be able to add a torrent!")
                            Spacer()
                        }.padding(.top)
                    }
                }
            }
            
            if serverConnections.count > 0 {
                Section {
                    Button(action: startDownload) {
                        Label("Start Download", systemImage: "square.and.arrow.down.on.square")
                    }.disabled(selectedServers.count == 0)
                }
            }
        }
        .navigationTitle("Add Torrent")
        .alert(isPresented: showingError) {
            Alert(title: Text("Error!"), message: Text(errorMessage!), dismissButton: .default(Text("Ok")))
        }.onAppear {
            if let s = server {
                selectedServers = [s]
            }
        }
        
        #if os(macOS)
        return form
        #else
        return
            form.navigationBarItems(trailing: Button(action: {
                presentation.dismiss()
            }) {
                Text("Cancel")
                    .fontWeight(.medium)
            })
        #endif
    }
}

struct TorrentHandlerNavigationView: View {
    
    @Environment(\.presentationMode) private var presentation
    
    let torrent: LocalTorrent
    let server: Server?
    
    var body: some View {
        let form = TorrentHandlerView(presentation: presentation,
                                      torrent: torrent,
                                      server: server)
        
        #if os(macOS)
        return form
        #else
        return NavigationView {
            form
        }
        #endif
    }
}

struct TorrentHandlerNavigationView_Previews: PreviewProvider {

    static var previews: some View {
        TorrentHandlerNavigationView(torrent: PreviewMockData.localTorrentMagnet,
                                     server: nil)
    }
}