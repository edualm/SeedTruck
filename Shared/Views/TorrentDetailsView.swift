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
        
        private func actionButton<Content: View>(
            action: @escaping () -> Void,
            style: ButtonStyle = .primary,
            @ViewBuilder content: () -> Content
        ) -> some View {
            Button(action: action) {
                content()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(style.backgroundColor)
                    .foregroundColor(style.foregroundColor)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private enum ButtonStyle {
            case primary
            case secondary
            case destructive
            
            var backgroundColor: Color {
                switch self {
                case .primary:
                    return .blue
                case .secondary:
                    return .gray
                case .destructive:
                    return .red
                }
            }
            
            var foregroundColor: Color {
                switch self {
                case .primary, .destructive:
                    return .white
                case .secondary:
                    return .primary
                }
            }
        }
        
        var body: some View {
            let startTorrentButton = actionButton(
                action: {
                    presenter.perform(.start) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                            presentation.dismiss()
                        }
                    }
                },
                style: .primary
            ) {
                #if os(watchOS)
                Text("Start")
                    .font(.headline)
                #else
                Label("Start Torrent", systemImage: "play.fill")
                    .font(.headline)
                #endif
            }
            
            let pauseTorrentButton = actionButton(
                action: {
                    presenter.perform(.pause) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                            presentation.dismiss()
                        }
                    }
                },
                style: .secondary
            ) {
                #if os(watchOS)
                Text("Pause")
                    .font(.headline)
                #else
                Label("Pause Torrent", systemImage: "pause.fill")
                    .font(.headline)
                #endif
            }
            
            let removeTorrentButton = actionButton(
                action: {
                    presenter.perform(.prepareForRemoval(deletingFiles: false))
                },
                style: .destructive
            ) {
                #if os(watchOS)
                Text("Remove")
                    .font(.headline)
                #else
                Label("Remove Torrent", systemImage: "xmark.circle.fill")
                    .font(.headline)
                #endif
            }
            
            let removeTorrentAndDataButton = actionButton(
                action: {
                    presenter.perform(.prepareForRemoval(deletingFiles: true))
                },
                style: .destructive
            ) {
                #if os(watchOS)
                Text("Remove Data")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                #else
                Label("Remove Data", systemImage: "trash.fill")
                    .font(.headline)
                #endif
            }
            
            VStack(spacing: 12) {
                switch presenter.torrent.status {
                case .downloading, .seeding:
                    pauseTorrentButton
                case .stopped:
                    startTorrentButton
                default:
                    EmptyView()
                }
                
                #if !os(watchOS)
                Divider()
                    .padding(.vertical, 4)
                #endif
                
                removeTorrentButton
                removeTorrentAndDataButton
            }
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
            innerBody.padding(.horizontal)
            #elseif os(tvOS) || os(watchOS)
            innerBody.navigationBarTitle("Torrent Detail")
            #else
            innerBody.navigationBarTitle("Torrent Detail").padding(.horizontal)
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
