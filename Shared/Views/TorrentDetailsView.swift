//
//  TorrentDetailsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentDetailsView: View {
    
    private struct NameView: View {
        
        let torrent: RemoteTorrent
        
        var body: some View {
            Box(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
                HStack {
                    Text(torrent.name)
                    Spacer()
                }.padding(.top)
            }
        }
    }
    
    private struct StatusView: View {
        
        let torrent: RemoteTorrent
        
        var body: some View {
            Box(label: Label("Status", systemImage: "exclamationmark.bubble")) {
                HStack {
                    if case RemoteTorrent.Status.downloading = torrent.status {
                        Text("\(torrent.status.displayableStatus) (\(String(format: "%.2f", torrent.progress * 100))%)")
                    } else {
                        Text(torrent.status.displayableStatus)
                    }
                    
                    Spacer()
                }.padding(.top)
            }
        }
    }
    
    private struct SpeedView: View {
        
        let torrent: RemoteTorrent
        
        var body: some View {
            switch torrent.status {
            case let .downloading(_, _, _, downloadRate, uploadRate):
                Box(label: Label("Speed", systemImage: "speedometer")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Download: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: downloadRate))", systemImage: "arrow.down.forward")
                            Label("Upload: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate))", systemImage: "arrow.up.forward")
                        }
                        Spacer()
                    }.padding(.top)
                }
                
            case let .seeding(_, uploadRate):
                Box(label: Label("Speed", systemImage: "speedometer")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Upload: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate))", systemImage: "arrow.up.forward")
                        }
                        Spacer()
                    }.padding(.top)
                }
                
            default:
                EmptyView()
            }
        }
    }
    
    private struct ActionsView: View {
        
        let actionHandler: TorrentDetailsActionHandler
        
        var body: some View {
            Button(action: {
                actionHandler.perform(.prepareForRemoval(deletingFiles: false))
            }) {
                #if os(watchOS)
                Text("Remove Torrent")
                #else
                Label("Remove Torrent", systemImage: "xmark")
                #endif
            }.padding(4)
            
            Button(action: {
                actionHandler.perform(.prepareForRemoval(deletingFiles: true))
            }) {
                #if os(watchOS)
                Text("Remove Torrent and Data")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.red)
                #else
                Label("Remove Torrent and Data", systemImage: "trash")
                    .foregroundColor(.red)
                #endif
            }.padding(4)
        }
    }
    
    @Environment(\.presentationMode) private var presentation
    
    let torrent: RemoteTorrent
    
    @ObservedObject var actionHandler: TorrentDetailsActionHandler
    
    var body: some View {
        let currentAlert = Binding<TorrentDetailsActionHandler.AlertIdentifier?>(
            get: { self.actionHandler.currentAlert },
            set: { self.actionHandler.currentAlert = $0 }
        )
        
        var view = AnyView(ScrollView {
            NameView(torrent: torrent)
            
            #if os(watchOS) || os(tvOS)
            Divider()
                .padding()
            #endif
            
            StatusView(torrent: torrent)
            
            #if os(watchOS) || os(tvOS)
            Divider()
                .padding()
            #endif
            
            SpeedView(torrent: torrent)
            
            #if os(watchOS) || os(tvOS)
            Divider()
                .padding()
            #endif
            
            #if os(tvOS)
            HStack {
                ActionsView(actionHandler: actionHandler)
            }
            #else
            Box(label: Label("Actions", systemImage: "wrench")) {
                VStack {
                    ActionsView(actionHandler: actionHandler)
                }.padding(.top)
            }
            #endif
        }
        .alert(item: currentAlert) {
            switch $0.id {
            case .confirmation:
                return Alert(title: Text("Are you sure?"),
                             message: Text("You are about to perform a destructive action.\n\nAre you really sure?"),
                             primaryButton: .destructive(Text("Confirm")) {
                                self.actionHandler.perform(.commit) {
                                    self.presentation.wrappedValue.dismiss()
                                }
                             }, secondaryButton: .cancel())
                
            case .error:
                return Alert(title: Text("Error!"),
                             message: Text("The requested action couldn't be completed."),
                             dismissButton: .default(Text("Ok")))
            }
        })
        
        #if !os(macOS)
        view = AnyView(view.navigationBarTitle("Torrent Detail"))
        #endif
        
        #if os(watchOS) || os(tvOS)
        return view
        #else
        return view.padding()
        #endif
    }
}

struct TorrentDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentDetailsView(torrent: PreviewMockData.remoteTorrent,
                           actionHandler: .init(server: PreviewMockData.server,
                                                torrent: PreviewMockData.remoteTorrent))
        
    }
}
