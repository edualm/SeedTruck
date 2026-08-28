//
//  TorrentPreviewHTMLRenderer.swift
//  SeedTruck
//

import Foundation

enum TorrentPreviewHTMLRenderer {

    static let maximumDisplayedFiles = 250

    static func preview(
        for metadata: LocalTorrent.Metadata,
        sourceFileName: String
    ) -> Data {
        let displayedFiles = metadata.files.prefix(maximumDisplayedFiles)
        let remainingFileCount = metadata.files.count - displayedFiles.count
        let privacyFact = metadata.isPrivate.map { isPrivate in
            """
            <div class="fact">
                <span class="label">Access</span>
                <strong>\(isPrivate ? "Private" : "Public")</strong>
            </div>
            """
        } ?? ""

        let fileRows = displayedFiles.map { file in
            """
            <tr>
                <td class="path">\(escaped(limited(file.path)))</td>
                <td class="size">\(escaped(ByteCountFormatter.humanReadableFileSize(bytes: file.size)))</td>
            </tr>
            """
        }.joined(separator: "\n")

        let remainingNotice = remainingFileCount > 0
            ? "<p class=\"remainder\">Showing the first \(maximumDisplayedFiles.formatted()) files. \(remainingFileCount.formatted()) more are not shown.</p>"
            : ""

        return htmlDocument(
            title: metadata.name,
            body: """
            <main>
                <header>
                    <div class="document-icon" aria-hidden="true">T</div>
                    <div class="heading">
                        <p class="eyebrow">Torrent</p>
                        <h1>\(escaped(metadata.name))</h1>
                        <p class="source">\(escaped(sourceFileName))</p>
                    </div>
                </header>

                <section class="facts" aria-label="Torrent summary">
                    <div class="fact">
                        <span class="label">Total size</span>
                        <strong>\(escaped(ByteCountFormatter.humanReadableFileSize(bytes: metadata.totalSize)))</strong>
                    </div>
                    <div class="fact">
                        <span class="label">Files</span>
                        <strong>\(metadata.files.count.formatted())</strong>
                    </div>
                    \(privacyFact)
                </section>

                <section class="contents">
                    <div class="section-heading">
                        <h2>Contents</h2>
                        <span>\(metadata.files.count.formatted()) \(metadata.files.count == 1 ? "file" : "files")</span>
                    </div>
                    <div class="table-frame">
                        <table>
                            <thead>
                                <tr>
                                    <th scope="col">Path</th>
                                    <th scope="col">Size</th>
                                </tr>
                            </thead>
                            <tbody>
                                \(fileRows)
                            </tbody>
                        </table>
                    </div>
                    \(remainingNotice)
                </section>
            </main>
            """
        )
    }

    static func errorPreview(sourceFileName: String, message: String) -> Data {
        htmlDocument(
            title: "Unable to Preview Torrent",
            body: """
            <main class="error-page">
                <div class="error-icon" aria-hidden="true">!</div>
                <p class="eyebrow">Torrent</p>
                <h1>Unable to Preview Torrent</h1>
                <p class="source">\(escaped(sourceFileName))</p>
                <p class="error-message">\(escaped(message))</p>
            </main>
            """
        )
    }

    private static func htmlDocument(title: String, body: String) -> Data {
        let html = """
        <!doctype html>
        <html lang="en">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(escaped(title))</title>
            <style>
                :root {
                    color-scheme: light dark;
                    --accent: #e96818;
                    --accent-soft: #fff0e6;
                    --background: #f6f4f1;
                    --surface: #ffffff;
                    --text: #211d1a;
                    --secondary: #756d66;
                    --border: #ded8d2;
                    --row: #faf8f6;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --accent: #ff8a42;
                        --accent-soft: #3d2418;
                        --background: #171513;
                        --surface: #23201e;
                        --text: #f5f1ed;
                        --secondary: #b9afa7;
                        --border: #45403c;
                        --row: #2a2724;
                    }
                }
                * { box-sizing: border-box; }
                body {
                    margin: 0;
                    background: var(--background);
                    color: var(--text);
                    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                    font-size: 15px;
                    line-height: 1.45;
                }
                main {
                    width: min(920px, 100%);
                    margin: 0 auto;
                    padding: 44px 40px 52px;
                }
                header {
                    display: flex;
                    align-items: flex-start;
                    gap: 20px;
                }
                .document-icon {
                    display: grid;
                    place-items: center;
                    flex: 0 0 64px;
                    height: 72px;
                    border-radius: 16px 16px 16px 5px;
                    background: var(--accent);
                    color: white;
                    font-size: 28px;
                    font-weight: 800;
                    box-shadow: 0 10px 24px rgba(108, 45, 8, 0.20);
                }
                .heading { min-width: 0; }
                .eyebrow {
                    margin: 0 0 4px;
                    color: var(--accent);
                    font-size: 12px;
                    font-weight: 750;
                    letter-spacing: 0.13em;
                    text-transform: uppercase;
                }
                h1 {
                    margin: 0;
                    font-size: clamp(25px, 4vw, 38px);
                    line-height: 1.12;
                    overflow-wrap: anywhere;
                }
                .source {
                    margin: 8px 0 0;
                    color: var(--secondary);
                    overflow-wrap: anywhere;
                }
                .facts {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
                    gap: 12px;
                    margin: 32px 0 38px;
                }
                .fact {
                    min-width: 0;
                    padding: 17px 18px;
                    border: 1px solid var(--border);
                    border-radius: 14px;
                    background: var(--surface);
                }
                .fact .label {
                    display: block;
                    margin-bottom: 3px;
                    color: var(--secondary);
                    font-size: 12px;
                    font-weight: 650;
                    letter-spacing: 0.03em;
                    text-transform: uppercase;
                }
                .fact strong {
                    display: block;
                    overflow: hidden;
                    font-size: 17px;
                    font-variant-numeric: tabular-nums;
                    text-overflow: ellipsis;
                    white-space: nowrap;
                }
                .section-heading {
                    display: flex;
                    align-items: baseline;
                    justify-content: space-between;
                    gap: 16px;
                    margin-bottom: 12px;
                }
                h2 { margin: 0; font-size: 20px; }
                .section-heading span { color: var(--secondary); font-size: 13px; }
                .table-frame {
                    overflow: hidden;
                    border: 1px solid var(--border);
                    border-radius: 15px;
                    background: var(--surface);
                }
                table { width: 100%; border-collapse: collapse; }
                th, td { padding: 12px 15px; text-align: left; }
                th {
                    background: var(--accent-soft);
                    color: var(--secondary);
                    font-size: 12px;
                    font-weight: 700;
                    letter-spacing: 0.04em;
                    text-transform: uppercase;
                }
                th:last-child, td.size { width: 1%; text-align: right; white-space: nowrap; }
                tbody tr:nth-child(even) { background: var(--row); }
                tbody tr + tr { border-top: 1px solid var(--border); }
                td.path { overflow-wrap: anywhere; }
                td.size { color: var(--secondary); font-variant-numeric: tabular-nums; }
                .remainder {
                    margin: 12px 4px 0;
                    color: var(--secondary);
                    font-size: 13px;
                }
                .error-page {
                    display: flex;
                    min-height: 520px;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    text-align: center;
                }
                .error-icon {
                    display: grid;
                    place-items: center;
                    width: 64px;
                    height: 64px;
                    margin-bottom: 22px;
                    border-radius: 18px;
                    background: var(--accent-soft);
                    color: var(--accent);
                    font-size: 32px;
                    font-weight: 800;
                }
                .error-message {
                    max-width: 560px;
                    margin: 22px 0 0;
                    padding: 16px 18px;
                    border: 1px solid var(--border);
                    border-radius: 14px;
                    background: var(--surface);
                    color: var(--secondary);
                }
                @media (max-width: 620px) {
                    main { padding: 28px 18px 36px; }
                    header { gap: 14px; }
                    .document-icon { flex-basis: 52px; height: 59px; border-radius: 13px 13px 13px 4px; font-size: 23px; }
                    .facts { grid-template-columns: 1fr; gap: 8px; margin: 24px 0 30px; }
                    .fact { display: flex; align-items: baseline; justify-content: space-between; gap: 12px; padding: 13px 15px; }
                    .fact .label { margin: 0; }
                    .fact strong { font-size: 15px; }
                    th, td { padding: 10px 12px; }
                }
            </style>
        </head>
        <body>
            \(body)
        </body>
        </html>
        """

        return Data(html.utf8)
    }

    private static func limited(_ path: String) -> String {
        guard path.count > 1_024 else {
            return path
        }
        return String(path.prefix(1_021)) + "..."
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
