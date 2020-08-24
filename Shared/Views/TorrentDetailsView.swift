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
            GroupBox(label: Label("Name", systemImage: "pencil.and.ellipsis.rectangle")) {
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
            GroupBox(label: Label("Status", systemImage: "exclamationmark.bubble")) {
                HStack {
                    Text(torrent.status.displayableStatus)
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
                GroupBox(label: Label("Speed", systemImage: "speedometer")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Download: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: downloadRate))", systemImage: "chevron.down")
                            Label("Upload: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate))", systemImage: "chevron.up")
                        }
                        Spacer()
                    }.padding(.top)
                }
                
            case let .seeding(_, uploadRate):
                GroupBox(label: Label("Speed", systemImage: "speedometer")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Upload: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate))", systemImage: "chevron.up")
                        }
                        Spacer()
                    }.padding(.top)
                }
                
            default:
                EmptyView()
            }
        }
    }
    
    @Environment(\.presentationMode) private var presentation
    
    let torrent: RemoteTorrent
    
    @ObservedObject var presenter: TorrentDetailsViewPresenter
    
    var body: some View {
        let currentAlert = Binding<TorrentDetailsViewPresenter.AlertIdentifier?>(
            get: { self.presenter.currentAlert },
            set: { self.presenter.currentAlert = $0 }
        )
        
        return ScrollView {
            NameView(torrent: torrent)
            StatusView(torrent: torrent)
            SpeedView(torrent: torrent)
            GroupBox(label: Label("Actions", systemImage: "wrench")) {
                VStack {
                    Button(action: {
                        presenter.perform(.prepareForRemoval(deletingFiles: false))
                    }) {
                        Label("Remove Torrent", systemImage: "xmark")
                    }.padding(4)
                    
                    Button(action: {
                        presenter.perform(.prepareForRemoval(deletingFiles: true))
                    }) {
                        Label("Remove Torrent and Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }.padding(4)
                }.padding(.top)
            }
        }
        .padding()
        .navigationBarTitle("Torrent Detail")
        .alert(item: currentAlert) {
            switch $0.id {
            case .confirmation:
                return Alert(title: Text("Are you sure?"),
                             message: Text("You are about to perform a destructive action.\n\nAre you really sure?"),
                             primaryButton: .destructive(Text("Confirm")) {
                                self.presenter.perform(.commit) {
                                    self.presentation.wrappedValue.dismiss()
                                }
                             }, secondaryButton: .cancel())
                
            case .error:
                return Alert(title: Text("Error!"),
                             message: Text("The requested action couldn't be completed."),
                             dismissButton: .default(Text("Ok")))
            }
        }
    }
}

struct TorrentDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentDetailsView(torrent: PreviewMockData.torrent,
                           presenter: .init(server: PreviewMockData.server,
                                            torrent: PreviewMockData.torrent))
            
    }
}
