// Captures one app's main window with ScreenCaptureKit, without its shadow: a PNG still, or an H.264 video that
// runs until interrupted (SIGINT or SIGTERM) or for a set duration. The terminal running it needs Screen
// Recording permission once (System Settings > Privacy & Security).
//
//   swiftc -O -parse-as-library scripts/store/mac-capture.swift -o .build/store/mac-capture
//   mac-capture --pid <pid> --out window.png
//   mac-capture --pid <pid> --video window.mov [--duration <seconds>] [--started <file>]
//
// `--started` receives the Unix time of the video's first frame once it's written, to line the video up with
// the app's showcase log.

import AppKit
import AVFoundation
import CoreMedia
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

@main
struct MacCapture {
    static func main() async {
        // ScreenCaptureKit needs a window server connection, which a command-line tool doesn't make on its own.
        _ = NSApplication.shared
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("mac-capture: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run(_ arguments: [String]) async throws {
        func value(_ flag: String) -> String? {
            arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        guard let pid = value("--pid").flatMap(pid_t.init) else { throw Failure("Pass --pid <pid>.") }
        let (filter, sheetsRect) = try await windowFilter(pid: pid)
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        let rect = sheetsRect ?? filter.contentRect
        configuration.width = Int((rect.width * scale).rounded())
        configuration.height = Int((rect.height * scale).rounded())
        configuration.ignoreShadowsSingleWindow = true
        if let sheetsRect {
            // The window and its sheets, cut from the display: the rest of the screen left out and clear.
            configuration.sourceRect = sheetsRect
            configuration.ignoreShadowsDisplay = true
            configuration.backgroundColor = .clear
        }
        // The display's own space may be wider; the App Store expects sRGB.
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.showsCursor = false

        if let out = value("--out") {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            try writePNG(image, to: URL(fileURLWithPath: out))
        } else if let video = value("--video") {
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            configuration.queueDepth = 6
            let recorder = try Recorder(url: URL(fileURLWithPath: video), width: configuration.width,
                                        height: configuration.height,
                                        started: value("--started").map(URL.init(fileURLWithPath:)))
            let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: recorder.queue)
            try await stream.startCapture()
            await waitForStop(duration: value("--duration").flatMap(Double.init))
            try await stream.stopCapture()
            try await recorder.finish()
        } else {
            throw Failure("Pass --out <file.png> or --video <file.mov>.")
        }
    }

    /// The app's largest on-screen window at the normal level: its main window, not a menu or popover. A sheet is
    /// a window of its own, over its parent; when one is open, the filter takes the display with just the window
    /// and its sheets, and the rectangle they cover in the display's points.
    static func windowFilter(pid: pid_t) async throws -> (SCContentFilter, CGRect?) {
        let deadline = Date().addingTimeInterval(10)
        while true {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            let windows = content.windows
                .filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 && $0.isOnScreen }
            let window = windows.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            if let window {
                let sheets = windows.filter { $0.windowID != window.windowID && $0.frame.intersects(window.frame) }
                guard !sheets.isEmpty,
                      let display = content.displays.first(where: { $0.frame.intersects(window.frame) }) else {
                    return (SCContentFilter(desktopIndependentWindow: window), nil)
                }
                let covered = sheets.reduce(window.frame) { $0.union($1.frame) }
                let rect = covered.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
                return (SCContentFilter(display: display, including: [window] + sheets), rect)
            }
            guard Date() < deadline else { throw Failure("No on-screen window for process \(pid).") }
            try await Task.sleep(for: .milliseconds(200))
        }
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString,
                                                                1, nil) else { throw Failure("Cannot write \(url.path).") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure("Cannot write \(url.path).") }
    }

    /// Returns after `duration`, or when SIGINT or SIGTERM arrives.
    static func waitForStop(duration: Double?) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let once = Once(continuation)
            for signalNumber in [SIGINT, SIGTERM] {
                signal(signalNumber, SIG_IGN)
                let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
                source.setEventHandler { once.resume() }
                source.resume()
                Once.sources.append(source)
            }
            if let duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { once.resume() }
            }
        }
    }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

final class Once: @unchecked Sendable {
    nonisolated(unsafe) static var sources: [any DispatchSourceSignal] = []
    private var continuation: CheckedContinuation<Void, Never>?
    init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

/// Writes complete screen frames to an H.264 file, timed from the first one.
final class Recorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "mac-capture.recorder")
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let started: URL?
    private var sessionStarted = false

    init(url: URL, width: Int, height: Int, started: URL?) throws {
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 40_000_000,
                                              AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
        ])
        input.expectsMediaDataInRealTime = true
        writer.add(input)
        self.started = started
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid, isComplete(buffer) else { return }
        if !sessionStarted {
            guard writer.startWriting() else { return }
            writer.startSession(atSourceTime: buffer.presentationTimeStamp)
            sessionStarted = true
            if let started {
                try? String(Date().timeIntervalSince1970).write(to: started, atomically: true, encoding: .utf8)
            }
        }
        if input.isReadyForMoreMediaData { input.append(buffer) }
    }

    /// Idle and blank frames carry no new image.
    private func isComplete(_ buffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
            as? [[SCStreamFrameInfo: Any]], let raw = attachments.first?[.status] as? Int,
            let status = SCFrameStatus(rawValue: raw) else { return false }
        return status == .complete
    }

    func finish() async throws {
        await withCheckedContinuation { continuation in queue.async { continuation.resume() } }
        guard sessionStarted else { throw Failure("No frames were captured.") }
        input.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }
    }
}
