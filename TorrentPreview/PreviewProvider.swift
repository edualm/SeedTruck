//
//  PreviewProvider.swift
//  TorrentPreview
//
//  Created by Eduardo Almeida on 27/08/2026.
//

#if os(macOS)
import Quartz
#else
import QuickLook
#endif
import UniformTypeIdentifiers

final class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        return QLPreviewReply(
            dataOfContentType: .html,
            contentSize: CGSize(width: 820, height: 720)
        ) { reply in
            reply.stringEncoding = .utf8

            do {
                let torrent = try LocalTorrent(validating: fileURL)
                guard case .torrent(_, let metadata, _) = torrent else {
                    throw TorrentImportError.unsupportedType
                }
                return TorrentPreviewHTMLRenderer.preview(
                    for: metadata,
                    sourceFileName: fileURL.lastPathComponent
                )
            } catch {
                return TorrentPreviewHTMLRenderer.errorPreview(
                    sourceFileName: fileURL.lastPathComponent,
                    message: error.localizedDescription
                )
            }
        }
    }
}
