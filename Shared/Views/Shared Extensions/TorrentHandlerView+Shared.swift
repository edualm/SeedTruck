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
            VStack(alignment: .leading, spacing: 6) {
                Label("No Servers Configured", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Add a torrent server in Settings before starting this download.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
    
    struct TorrentSummaryView: View {
        
        let torrent: LocalTorrent

        private var displayName: String {
            torrent.name ?? "Unnamed Torrent"
        }

        private var sourceDescription: String {
            switch torrent {
            case .magnet:
                return "Magnet link"
            case .torrent:
                return "Torrent file"
            }
        }

        private var sourceSystemImage: String {
            switch torrent {
            case .magnet:
                return "link"
            case .torrent:
                return "doc"
            }
        }

        @ViewBuilder
        private var facts: some View {
            SummaryFact(title: sourceDescription, systemImage: sourceSystemImage)

            if let size = torrent.size {
                SummaryFact(
                    title: ByteCountFormatter.humanReadableFileSize(bytes: size),
                    systemImage: "internaldrive"
                )
            }

            if let files = torrent.files {
                SummaryFact(
                    title: files.count == 1 ? "1 file" : "\(files.count) files",
                    systemImage: "doc.on.doc"
                )
            }

            if torrent.isPrivate == true {
                SummaryFact(title: "Private", systemImage: "lock.fill")
            }
        }

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: sourceSystemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    #if os(macOS)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 14) {
                            facts
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            facts
                        }
                    }
                    #else
                    VStack(alignment: .leading, spacing: 5) {
                        facts
                    }
                    #endif
                }

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
        }

        private struct SummaryFact: View {

            let title: String
            let systemImage: String

            var body: some View {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .frame(width: 18, height: 18)
                        .accessibilityHidden(true)
                    Text(title)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize()
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
        loadedConnectionDetails = selectedServers.map(\.connectionDetails)
        
        loadLabelsFromServer()
    }
    
    func startDownload() {
        guard !processing, !selectedServers.isEmpty else {
            return
        }

        processing = true

        let addRequest = TorrentAddRequest(torrent: torrent, tags: selectedLabels)
        let requests = selectedServers.map { (name: $0.name, connection: $0.connection) }

        Task {
            let errors: [(String, String)] = await withTaskGroup(of: (String, String)?.self) { group in
                for request in requests {
                    group.addTask {
                        do {
                            try await request.connection.addTorrent(addRequest)
                            return nil
                        } catch {
                            return (request.name, error.localizedDescription)
                        }
                    }
                }

                var errors: [(String, String)] = []

                for await result in group {
                    if let result {
                        errors.append(result)
                    }
                }

                return errors
            }

            processing = false

            if errors.isEmpty {
                NotificationCenter.default.post(name: .updateTorrentListView, object: nil)
                dismissHandler()
            } else {
                let errorDetails = errors
                    .map { "\"\($0.0)\": \($0.1)" }
                    .joined(separator: "\n")
                errorMessage = "An error has occurred while adding the torrent to the following servers:\n\n" +
                    "\(errorDetails)\n\nPlease look at the inserted data and try again."
            }
        }
    }
    
    var sharedBody: some View {
        normalBody
            .navigationTitle("Add Torrent")
            .onAppear(perform: onAppear)
            .onChange(of: selectedServers.map(\.connectionDetails)) { _, connectionDetails in
                guard connectionDetails != loadedConnectionDetails else {
                    return
                }

                loadedConnectionDetails = connectionDetails
                serverLabels = []
                selectedLabels = []
                loadLabelsFromServer()
            }
    }
}
