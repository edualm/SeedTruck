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
                            .font(.caption)
                            .frame(width: 12, alignment: .center)
                            .padding(.trailing, 4)
                        Text(label)
                            .font(.caption)
                    }
                    Spacer()
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
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
            let button = Button(action: action) {
                content()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(style.backgroundView)
                    .foregroundColor(style.foregroundColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style.borderColor, lineWidth: style.borderWidth)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if #available(iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 18.0, *) {
                return button
                    .glassEffect(.regular.tint(style.glassTintColor).interactive())
            } else {
                return button
            }
        }
        
        private enum ButtonStyle {
            case primary
            case secondary
            case destructive
            
            @ViewBuilder
            var backgroundView: some View {
                if #available(iOS 26.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *) {
                    // Use clear background for glass effect - the glassEffect modifier will handle the appearance
                    Color.clear
                } else {
                    // Fallback solid colors for older OS versions
                    switch self {
                    case .primary:
                        Color.blue
                    case .secondary:
                        Color.gray
                    case .destructive:
                        Color.red
                    }
                }
            }
            
            var foregroundColor: Color {
                if #available(iOS 26.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *) {
                    // Enhanced colors for glass effect
                    switch self {
                    case .primary:
                        return .primary
                    case .secondary:
                        return .primary
                    case .destructive:
                        return .primary
                    }
                } else {
                    // Original colors for older versions
                    switch self {
                    case .primary, .destructive:
                        return .white
                    case .secondary:
                        return .primary
                    }
                }
            }
            
            var borderColor: Color {
                if #available(iOS 26.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *) {
                    // No border needed with native glass effects
                    return .clear
                } else {
                    return .clear
                }
            }
            
            var borderWidth: CGFloat {
                if #available(iOS 26.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *) {
                    // No border needed with native glass effects
                    return 0
                } else {
                    return 0
                }
            }

            @available(iOS 26.0, macOS 15.0, watchOS 11.0, tvOS 18.0, *)
            var glassTintColor: Color {
                switch self {
                case .primary:
                    return .blue.opacity(0.8)
                case .secondary:
                    return .gray.opacity(0.6)
                case .destructive:
                    return .red.opacity(0.8)
                }
            }
        }
        
        var body: some View {
            let startTorrentButton = actionButton(
                action: {
                    presenter.perform(.start)
                },
                style: .primary
            ) {
                #if os(watchOS)
                Text("Start")
                    .font(.headline)
                    .fontWeight(.semibold)
                #else
                Label("Start Torrent", systemImage: "play.fill")
                    .font(.headline)
                    .fontWeight(.semibold)
                #endif
            }
            
            let pauseTorrentButton = actionButton(
                action: {
                    presenter.perform(.pause)
                },
                style: .secondary
            ) {
                #if os(watchOS)
                Text("Pause")
                    .font(.headline)
                    .fontWeight(.semibold)
                #else
                Label("Pause Torrent", systemImage: "pause.fill")
                    .font(.headline)
                    .fontWeight(.semibold)
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
                    .fontWeight(.semibold)
                #else
                Label("Remove Torrent", systemImage: "xmark.circle.fill")
                    .font(.headline)
                    .fontWeight(.semibold)
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
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                #else
                Label("Remove Data", systemImage: "trash.fill")
                    .font(.headline)
                    .fontWeight(.semibold)
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
            Divider()
                .padding()
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
