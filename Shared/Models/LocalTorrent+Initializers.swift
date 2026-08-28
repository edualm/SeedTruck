//
//  LocalTorrent+Initializers.swift
//  SeedTruck
//
//  Created by Eduardo Almeida on 25/08/2020.
//

import Foundation

extension LocalTorrent {

    init?(url: URL) {
        try? self.init(validating: url)
    }

    init?(data: Data) {
        try? self.init(validating: data)
    }

    init(validating url: URL, limits: TorrentImportLimits = .appDefault) throws {
        if url.isFileURL {
            guard url.pathExtension.caseInsensitiveCompare("torrent") == .orderedSame else {
                throw TorrentImportError.unsupportedType
            }

            self = try LocalTorrent(
                validating: Self.readTorrentData(from: url, limits: limits),
                limits: limits
            )
        } else {
            let urlString = url.absoluteString
            guard urlString.lowercased().hasPrefix("magnet:") else {
                throw TorrentImportError.unsupportedType
            }

            self = .magnet(urlString, labels: [])
        }
    }

    init(validating data: Data, limits: TorrentImportLimits = .appDefault) throws {
        guard data.count <= limits.maximumEncodedBytes else {
            throw TorrentImportError.fileTooLarge(maximumBytes: limits.maximumEncodedBytes)
        }

        var parser = BencodeParser(data: data, limits: limits)
        let root = try parser.parseDocument()
        let metadata = try TorrentMetadataDecoder(root: root, bytes: parser.bytes, limits: limits).decode()
        self = .torrent(data: data, metadata: metadata, labels: [])
    }

    private static func readTorrentData(
        from url: URL,
        limits: TorrentImportLimits
    ) throws -> Data {
        #if os(iOS) || os(macOS)
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        #endif

        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile != false else {
                throw TorrentImportError.unreadableFile
            }
            if let fileSize = values.fileSize, fileSize > limits.maximumEncodedBytes {
                throw TorrentImportError.fileTooLarge(maximumBytes: limits.maximumEncodedBytes)
            }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: limits.maximumEncodedBytes + 1) ?? Data()
            guard data.count <= limits.maximumEncodedBytes else {
                throw TorrentImportError.fileTooLarge(maximumBytes: limits.maximumEncodedBytes)
            }
            return data
        } catch let error as TorrentImportError {
            throw error
        } catch {
            throw TorrentImportError.unreadableFile
        }
    }
}

private indirect enum BencodeValue {

    case integer(Int64)
    case bytes(Range<Int>)
    case list([BencodeValue])
    case dictionary([(Data, BencodeValue)])
}

private struct BencodeParser {

    let bytes: [UInt8]
    let limits: TorrentImportLimits

    private var index = 0
    private var nodeCount = 0

    init(data: Data, limits: TorrentImportLimits) {
        self.bytes = Array(data)
        self.limits = limits
    }

    mutating func parseDocument() throws -> BencodeValue {
        let value = try parseValue(depth: 0)
        guard index == bytes.count else {
            throw TorrentImportError.malformedMetadata
        }
        guard case .dictionary = value else {
            throw TorrentImportError.malformedMetadata
        }
        return value
    }

    private mutating func parseValue(depth: Int) throws -> BencodeValue {
        guard depth <= limits.maximumDepth else {
            throw TorrentImportError.metadataLimitExceeded
        }
        try recordNode()
        guard index < bytes.count else {
            throw TorrentImportError.malformedMetadata
        }

        switch bytes[index] {
        case ASCII.integer:
            return try parseInteger()
        case ASCII.list:
            return try parseList(depth: depth)
        case ASCII.dictionary:
            return try parseDictionary(depth: depth)
        case ASCII.zero...ASCII.nine:
            return .bytes(try parseByteString())
        default:
            throw TorrentImportError.malformedMetadata
        }
    }

    private mutating func parseInteger() throws -> BencodeValue {
        index += 1
        let start = index
        while index < bytes.count, bytes[index] != ASCII.end {
            index += 1
        }
        guard index < bytes.count, index > start else {
            throw TorrentImportError.malformedMetadata
        }

        let integerBytes = bytes[start..<index]
        guard integerBytes.count <= 20 else {
            throw TorrentImportError.malformedMetadata
        }
        if integerBytes.first == ASCII.minus {
            guard integerBytes.count > 1, integerBytes.dropFirst().first != ASCII.zero else {
                throw TorrentImportError.malformedMetadata
            }
        } else if integerBytes.count > 1, integerBytes.first == ASCII.zero {
            throw TorrentImportError.malformedMetadata
        }
        guard integerBytes.allSatisfy({ $0 == ASCII.minus || $0.isASCIIDigit }) else {
            throw TorrentImportError.malformedMetadata
        }

        let text = String(decoding: integerBytes, as: UTF8.self)
        guard let value = Int64(text) else {
            throw TorrentImportError.malformedMetadata
        }
        index += 1
        return .integer(value)
    }

    private mutating func parseList(depth: Int) throws -> BencodeValue {
        index += 1
        var values: [BencodeValue] = []
        while index < bytes.count, bytes[index] != ASCII.end {
            values.append(try parseValue(depth: depth + 1))
        }
        guard index < bytes.count else {
            throw TorrentImportError.malformedMetadata
        }
        index += 1
        return .list(values)
    }

    private mutating func parseDictionary(depth: Int) throws -> BencodeValue {
        index += 1
        var entries: [(Data, BencodeValue)] = []
        var keys: Set<Data> = []

        while index < bytes.count, bytes[index] != ASCII.end {
            try recordNode()
            guard bytes[index].isASCIIDigit else {
                throw TorrentImportError.malformedMetadata
            }
            let keyRange = try parseByteString()
            let key = Data(bytes[keyRange])
            guard keys.insert(key).inserted else {
                throw TorrentImportError.malformedMetadata
            }
            entries.append((key, try parseValue(depth: depth + 1)))
        }
        guard index < bytes.count else {
            throw TorrentImportError.malformedMetadata
        }
        index += 1
        return .dictionary(entries)
    }

    private mutating func parseByteString() throws -> Range<Int> {
        let lengthStart = index
        var length = 0
        while index < bytes.count, bytes[index].isASCIIDigit {
            let digit = Int(bytes[index] - ASCII.zero)
            guard length <= (Int.max - digit) / 10 else {
                throw TorrentImportError.malformedMetadata
            }
            length = length * 10 + digit
            index += 1
        }
        guard index < bytes.count,
              bytes[index] == ASCII.colon,
              index > lengthStart else {
            throw TorrentImportError.malformedMetadata
        }
        if index - lengthStart > 1, bytes[lengthStart] == ASCII.zero {
            throw TorrentImportError.malformedMetadata
        }

        index += 1
        guard length <= bytes.count - index else {
            throw TorrentImportError.malformedMetadata
        }
        let range = index..<(index + length)
        index += length
        return range
    }

    private mutating func recordNode() throws {
        nodeCount += 1
        guard nodeCount <= limits.maximumNodes else {
            throw TorrentImportError.metadataLimitExceeded
        }
    }
}

private struct TorrentMetadataDecoder {

    let root: BencodeValue
    let bytes: [UInt8]
    let limits: TorrentImportLimits

    func decode() throws -> LocalTorrent.Metadata {
        guard let info = value(for: "info", in: root),
              case .dictionary = info else {
            throw TorrentImportError.malformedMetadata
        }

        let name = try textValue(for: "name.utf-8", fallback: "name", in: info)
        guard !name.isEmpty else {
            throw TorrentImportError.malformedMetadata
        }

        guard let pieceLength = integerValue(for: "piece length", in: info), pieceLength > 0,
              let pieces = byteRange(for: "pieces", in: info), pieces.count.isMultiple(of: 20) else {
            throw TorrentImportError.malformedMetadata
        }

        let isPrivate: Bool?
        if let privateValue = value(for: "private", in: info) {
            guard case .integer(let flag) = privateValue, flag == 0 || flag == 1 else {
                throw TorrentImportError.malformedMetadata
            }
            isPrivate = flag == 1
        } else {
            isPrivate = nil
        }

        let length = integerValue(for: "length", in: info)
        let fileList = value(for: "files", in: info)
        guard (length == nil) != (fileList == nil) else {
            throw TorrentImportError.malformedMetadata
        }

        let files: [LocalTorrent.File]
        if let length {
            guard length >= 0 else {
                throw TorrentImportError.malformedMetadata
            }
            files = [.init(path: name, size: length)]
        } else {
            guard let fileList, case .list(let encodedFiles) = fileList, !encodedFiles.isEmpty else {
                throw TorrentImportError.malformedMetadata
            }
            guard encodedFiles.count <= limits.maximumFiles else {
                throw TorrentImportError.metadataLimitExceeded
            }
            files = try encodedFiles.map(decodeFile)
        }

        let totalSize = try files.reduce(Int64(0)) { total, file in
            let (sum, overflow) = total.addingReportingOverflow(file.size)
            guard !overflow else {
                throw TorrentImportError.malformedMetadata
            }
            return sum
        }

        let expectedPieceCount = totalSize == 0
            ? 0
            : ((totalSize - 1) / pieceLength) + 1
        guard Int64(pieces.count / 20) == expectedPieceCount else {
            throw TorrentImportError.malformedMetadata
        }

        return .init(name: name, isPrivate: isPrivate, files: files, totalSize: totalSize)
    }

    private func decodeFile(_ value: BencodeValue) throws -> LocalTorrent.File {
        guard case .dictionary = value,
              let length = integerValue(for: "length", in: value),
              length >= 0,
              let pathValue = self.value(for: "path.utf-8", in: value) ?? self.value(for: "path", in: value),
              case .list(let components) = pathValue,
              !components.isEmpty else {
            throw TorrentImportError.malformedMetadata
        }
        guard components.count <= limits.maximumPathComponents else {
            throw TorrentImportError.metadataLimitExceeded
        }

        let pathComponents = try components.map { component -> String in
            guard case .bytes(let range) = component else {
                throw TorrentImportError.malformedMetadata
            }
            let text = try decodeText(range)
            guard !text.isEmpty, text != ".", text != ".." else {
                throw TorrentImportError.malformedMetadata
            }
            return text
        }
        return .init(path: pathComponents.joined(separator: "/"), size: length)
    }

    private func textValue(
        for key: String,
        fallback: String,
        in dictionary: BencodeValue
    ) throws -> String {
        guard let range = byteRange(for: key, in: dictionary) ?? byteRange(for: fallback, in: dictionary) else {
            throw TorrentImportError.malformedMetadata
        }
        return try decodeText(range)
    }

    private func decodeText(_ range: Range<Int>) throws -> String {
        guard range.count <= limits.maximumTextBytes else {
            throw TorrentImportError.metadataLimitExceeded
        }
        guard let text = String(bytes: bytes[range], encoding: .utf8) else {
            throw TorrentImportError.malformedMetadata
        }
        return text
    }

    private func integerValue(for key: String, in dictionary: BencodeValue) -> Int64? {
        guard let value = value(for: key, in: dictionary), case .integer(let integer) = value else {
            return nil
        }
        return integer
    }

    private func byteRange(for key: String, in dictionary: BencodeValue) -> Range<Int>? {
        guard let value = value(for: key, in: dictionary), case .bytes(let range) = value else {
            return nil
        }
        return range
    }

    private func value(for key: String, in dictionary: BencodeValue) -> BencodeValue? {
        guard case .dictionary(let entries) = dictionary else {
            return nil
        }
        let encodedKey = Data(key.utf8)
        return entries.first(where: { $0.0 == encodedKey })?.1
    }
}

private extension UInt8 {

    var isASCIIDigit: Bool {
        self >= ASCII.zero && self <= ASCII.nine
    }
}

private enum ASCII {

    static let colon: UInt8 = 58
    static let dictionary: UInt8 = 100
    static let end: UInt8 = 101
    static let integer: UInt8 = 105
    static let list: UInt8 = 108
    static let minus: UInt8 = 45
    static let nine: UInt8 = 57
    static let zero: UInt8 = 48
}
