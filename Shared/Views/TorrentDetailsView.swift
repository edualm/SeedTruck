//
//  TorrentDetailsView.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import SwiftUI

struct TorrentDetailsView: View {
    
    #if os(macOS)
    static private let innerDetailPadding: Edge.Set = .horizontal
    #else
    static private let innerDetailPadding: Edge.Set = Edge.Set()
    #endif
    
    private struct MetadataView: View {
        
        let torrent: RemoteTorrent
        
        var body: some View {
            Box(label: Label("Metadata", systemImage: "doc.text.viewfinder")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(torrent.name).padding(.bottom)
                        Label("Size: \(ByteCountFormatter.humanReadableFileSize(bytes: torrent.size))", systemImage: "shippingbox")
                    }.padding(TorrentDetailsView.innerDetailPadding)
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
                            .padding(TorrentDetailsView.innerDetailPadding)
                    } else {
                        Text(torrent.status.displayableStatus)
                            .padding(TorrentDetailsView.innerDetailPadding)
                    }
                    
                    Spacer()
                }.padding(.top)
            }
        }
    }
    
    private struct StatsView: View {
        
        let torrent: RemoteTorrent
        
        var body: some View {
            switch torrent.status {
            case let .downloading(_, peersSending, peersReceiving, downloadRate, uploadRate, eta):
                Box(label: Label("Statistics", systemImage: "speedometer")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Seeders: \(peersSending)", systemImage: "person.and.arrow.left.and.arrow.right")
                            
                            Label("Leechers: \(peersReceiving)", systemImage: "person.3")
                                .padding(.top)
                            
                            Label("Download Rate: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: downloadRate))", systemImage: "arrow.down.forward")
                                .padding(.top)
                                
                            Label("Upload Rate: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate))", systemImage: "arrow.up.forward")
                                .padding(.top)
                            
                            if let humanReadableETA = eta.humanReadableDate {
                                Label("Time Remaining: \(humanReadableETA)", systemImage: "deskclock")
                                    .padding(.top)
                            }
                        }.padding(TorrentDetailsView.innerDetailPadding)
                        Spacer()
                    }.padding(.top)
                }
                
            case let .seeding(_, uploadRate, ratio, totalUploaded, secondsSeeding, _):
                Box(label: Label("Statistics", systemImage: "speedometer")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Label("Upload Rate: \(ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate))", systemImage: "arrow.up.forward")
                            
                            if let totalUploaded = totalUploaded {
                                Label("Uploaded: \(ByteCountFormatter.humanReadableFileSize(bytes: totalUploaded)) (Ratio: \(String(format: "%.2f", ratio)))", systemImage: "arrow.up.to.line")
                                    .padding(.top)
                            }
                            
                            if let humanReadableSeedingTime = secondsSeeding?.humanReadableDate {
                                Label("Seeding Time: \(humanReadableSeedingTime)", systemImage: "deskclock")
                                    .padding(.top)
                            }
                        }.padding(TorrentDetailsView.innerDetailPadding)
                        Spacer()
                    }.padding(.top)
                }
                
            default:
                EmptyView()
            }
        }
    }
    
    private struct ActionsView: View {
        
        @Binding var presentation: PresentationMode
        
        let presenter: TorrentDetailsPresenter
        
        var body: some View {
            let startTorrentButton = Button(action: {
                presenter.perform(.start) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        presentation.dismiss()
                    }
                }
            }) {
                #if os(watchOS)
                Text("Start Torrent")
                #else
                Label("Start Torrent", systemImage: "play")
                #endif
            }.padding(4)
            
            let pauseTorrentButton = Button(action: {
                presenter.perform(.pause) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        presentation.dismiss()
                    }
                }
            }) {
                #if os(watchOS)
                Text("Pause Torrent")
                #else
                Label("Pause Torrent", systemImage: "pause")
                #endif
            }.padding(4)
            
            let removeTorrentButton = Button(action: {
                presenter.perform(.prepareForRemoval(deletingFiles: false))
            }) {
                #if os(watchOS)
                Text("Remove Torrent")
                    .foregroundColor(.red)
                #else
                Label("Remove Torrent", systemImage: "xmark")
                    .foregroundColor(.red)
                #endif
            }.padding(4)
            
            let removeTorrentAndDataButton = Button(action: {
                presenter.perform(.prepareForRemoval(deletingFiles: true))
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
            
            let items = Group {
                switch presenter.torrent.status {
                case .downloading, .seeding:
                    pauseTorrentButton
                case .stopped:
                    startTorrentButton
                default:
                    EmptyView()
                }
                
                removeTorrentButton
                removeTorrentAndDataButton
            }
            
            #if (os(iOS) || os(watchOS))
            VStack {
                items
            }
            #else
            items
            #endif
        }
    }
    
    @Environment(\.presentationMode) private var presentation
    
    let torrent: RemoteTorrent
    
    @State var shouldShowEmptyView: Bool = false
    
    @ObservedObject var presenter: TorrentDetailsPresenter
    
    var innerBody: some View {
        ScrollView {
            MetadataView(torrent: torrent)
            
            #if os(watchOS) || os(tvOS)
            Divider()
                .padding()
            #endif
            
            StatusView(torrent: torrent)
            
            #if os(watchOS) || os(tvOS)
            Divider()
                .padding()
            #endif
            
            StatsView(torrent: torrent)
            
            #if os(watchOS) || os(tvOS)
            switch torrent.status {
            case .downloading, .seeding:
                Divider()
                    .padding()
            default:
                EmptyView()
            }
            #endif
            
            if presenter.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else {
                #if os(tvOS)
                HStack {
                    ActionsView(presentation: presentation, presenter: presenter)
                }
                #else
                Box(label: Label("Actions", systemImage: "wrench")) {
                    VStack {
                        ActionsView(presentation: presentation, presenter: presenter)
                            .centered()
                    }.padding(.top)
                }
                #endif
            }
        }
        .alert(item: $presenter.currentAlert) {
            switch $0.id {
            case .confirmation:
                return Alert(title: Text("Are you sure?"),
                             message: Text("You are about to perform a destructive action.\n\nAre you really sure?"),
                             primaryButton: .destructive(Text("Confirm")) {
                                self.presenter.perform(.commit) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                                        shouldShowEmptyView = true
                                        
                                        self.presentation.wrappedValue.dismiss()
                                    }
                                }
                             }, secondaryButton: .cancel())
                
            case .error:
                return Alert(title: Text("Error!"),
                             message: Text("The requested action couldn't be completed."),
                             dismissButton: .default(Text("Ok")))
            }
        }
    }
    
    var body: some View {
        if shouldShowEmptyView {
            EmptyView()
        } else {
            #if os(macOS)
            innerBody.padding()
            #elseif os(tvOS) || os(watchOS)
            innerBody.navigationBarTitle("Torrent Detail")
            #else
            innerBody.navigationBarTitle("Torrent Detail").padding()
            #endif
        }
    }
}

struct TorrentDetailsView_Previews: PreviewProvider {
    
    static var previews: some View {
        TorrentDetailsView(torrent: PreviewMockData.remoteTorrent,
                           presenter: .init(server: PreviewMockData.server,
                                                torrent: PreviewMockData.remoteTorrent))
        
    }
}
