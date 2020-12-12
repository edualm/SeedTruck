//
//  TorrentHandlerView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import SwiftUI

struct TorrentHandlerView: View {
    
    typealias CloseHandler = () -> ()
    
    @FetchRequest(
        entity: Server.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Server.name, ascending: true)
        ]
    ) private var serverConnections: FetchedResults<Server>
    
    @State var errorMessage: String? = nil
    @State var selectedServers: [Server] = []
    
    let torrent: LocalTorrent
    let server: Server?
    let closeHandler: CloseHandler?
    
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
                        closeHandler?()
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
        
        #if os(macOS)
        let formHeader = Text("Torrent Metadata")
            .font(.largeTitle)
        let serversHeader = Text("Server(s)")
            .font(.largeTitle)
        #else
        let formHeader = Text("Torrent Metadata")
        let serversHeader = Text("Server(s)")
        #endif
        
        let form = Form {
            Section(header: formHeader) {
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
                        Text(ByteCountFormatter.humanReadableFileSize(bytes: Int64(size)))
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
                
                #if os(macOS)
                VStack {}
                    .opacity(0.01)
                    .padding(2)
                #endif
            }
            
            if server == nil {
                if serverConnections.count > 0 {
                    Section(header: serversHeader) {
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
            
            #if os(macOS)
            VStack {}
                .opacity(0.01)
                .padding(2)
            #endif
            
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
        return form.padding()
        #else
        return
            form.navigationBarItems(trailing: Button(action: { closeHandler?() }) {
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
        let closeHandler: TorrentHandlerView.CloseHandler = {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
            }
            
            #if os(macOS)
            Application.closeMainWindow()
            #else
            presentation.wrappedValue.dismiss()
            #endif
        }
        
        let form = TorrentHandlerView(torrent: torrent,
                                      server: server,
                                      closeHandler: closeHandler)
        
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
