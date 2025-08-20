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
        
        private struct MetadataRow: View {
            let label: String
            let value: String
            let icon: String
            
            var body: some View {
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(width: 12, alignment: .center)
                            .padding(.trailing, 4)
                        Text(label)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Spacer()
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 2)
            }
        }
        
        var body: some View {
            Box(label: Label("Details", systemImage: "doc.text.viewfinder")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(torrent.name)
                        .font(.headline)
                        .fontWeight(.regular)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(spacing: 6) {
                        MetadataRow(
                            label: "Status",
                            value: torrent.status.displayableStatus,
                            icon: "circle.fill"
                        )
                        
                        MetadataRow(
                            label: "Size",
                            value: ByteCountFormatter.humanReadableFileSize(bytes: torrent.size),
                            icon: "externaldrive"
                        )
                        
                        if !torrent.labels.isEmpty {
                            MetadataRow(
                                label: "Labels",
                                value: torrent.labels.joined(separator: ", "),
                                icon: "tag"
                            )
                        }
                        
                        if torrent.status.simple == .downloading {
                            MetadataRow(
                                label: "Progress",
                                value: "\(String(format: "%.1f", torrent.progress * 100))%",
                                icon: "chart.bar.fill"
                            )
                        }
                        
                        switch torrent.status {
                        case let .downloading(_, peersSending, peersReceiving, downloadRate, uploadRate, eta):
                            MetadataRow(
                                label: "Seeders",
                                value: "\(peersSending)",
                                icon: "person.and.arrow.left.and.arrow.right"
                            )
                            
                            MetadataRow(
                                label: "Leechers",
                                value: "\(peersReceiving)",
                                icon: "person.3"
                            )
                            
                            MetadataRow(
                                label: "Download Speed",
                                value: ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: downloadRate),
                                icon: "arrow.down.forward"
                            )
                            
                            MetadataRow(
                                label: "Upload Speed",
                                value: ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate),
                                icon: "arrow.up.forward"
                            )
                            
                            if let humanReadableETA = eta.humanReadableDate {
                                MetadataRow(
                                    label: "Time Remaining",
                                    value: humanReadableETA,
                                    icon: "clock"
                                )
                            }
                            
                        case let .seeding(_, uploadRate, ratio, totalUploaded, secondsSeeding, _):
                            MetadataRow(
                                label: "Upload Speed",
                                value: ByteCountFormatter.humanReadableTransmissionSpeed(bytesPerSecond: uploadRate),
                                icon: "arrow.up.forward"
                            )
                            
                            MetadataRow(
                                label: "Ratio",
                                value: String(format: "%.2f", ratio),
                                icon: "arrow.up.arrow.down"
                            )
                            
                            if let totalUploaded = totalUploaded {
                                MetadataRow(
                                    label: "Uploaded",
                                    value: ByteCountFormatter.humanReadableFileSize(bytes: totalUploaded),
                                    icon: "arrow.up.to.line"
                                )
                            }
                            
                            if let humanReadableSeedingTime = secondsSeeding?.humanReadableDate {
                                MetadataRow(
                                    label: "Seeding Time",
                                    value: humanReadableSeedingTime,
                                    icon: "deskclock"
                                )
                            }
                            
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(TorrentDetailsView.innerDetailPadding)
                .padding(.top)
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
                        DispatchQueue.main.async {
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
                        DispatchQueue.main.async {
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
            #if os(macOS)
                .padding(.top)
            #endif
            
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
                #if os(macOS)
                    .padding(.top)
                #endif
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
                                    DispatchQueue.main.async {
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
