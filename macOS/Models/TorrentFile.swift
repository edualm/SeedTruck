//
//  TorrentFile.swift
//  SeedTruck (macOS)
//
//  Created by Eduardo Almeida on 16/11/2020.
//

import SwiftUI

struct TorrentFile: FileDocument {
    
    static var readableContentTypes = [UTI.torrent]
    
    let localTorrent: LocalTorrent
    
    init(configuration: ReadConfiguration) throws {
        localTorrent = LocalTorrent(data: configuration.file.regularFileContents!)!
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return configuration.existingFile!
    }
}
