//
//  TorrentHandlerView+Shared.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 12/12/2020.
//

import SwiftUI

extension TorrentHandlerView {
    
    struct NoServersWarningView: View {
        
        var body: some View {
            GroupBox(label: Label("Oops!", systemImage: "exclamationmark.triangle")) {
                HStack {
                    Text("You must first configure at least one server in the app in order to be able to add a torrent!")
                    Spacer()
                }.padding(.top)
            }
        }
    }
    
    struct InfoSectionView: View {
        
        let torrent: LocalTorrent
        
        var body: some View {
            Group {
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
            }
        }
    }
    
    var showingError: Binding<Bool> {
        Binding<Bool>(
            get: { errorMessage != nil },
            set: {
                if $0 == false {
                    errorMessage = nil
                }
            }
        )
    }
    
    func onAppear() {
        if let s = server {
            selectedServers = [s]
        } else if serverConnections.count == 1 {
            selectedServers = [serverConnections[0]]
        }
        
        selectedLabels = torrent.labels
    }
    
    func startDownload() {
        processing = true
        
        var remaining = selectedServers.count
        var errors: [(Server, Error)] = []
        
        selectedServers.forEach { server in
            server.connection.addTorrent(torrent, labels: selectedLabels) {
                switch $0 {
                case .success:
                    ()
                    
                case .failure(let error):
                    errors.append((server, error))
                }
                
                remaining = remaining - 1
                
                if remaining == 0 {
                    processing = false
                    
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
    
    var processingBody: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .padding()
    }
    
    var sharedBody: some View {
        Group {
            if processing {
                processingBody
            } else {
                normalBody
            }
        }
        .navigationTitle("Add Torrent")
        .onAppear(perform: onAppear)
    }
}
