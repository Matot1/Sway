import AppKit
import Combine
import CryptoKit

struct ClipboardScreenshot: Identifiable {
    let id: UUID
    let fingerprint: UInt64
    let thumbnail: NSImage
    let payload: Data
    let payloadType: NSPasteboard.PasteboardType
}

final class ClipboardScreenshotManager: ObservableObject {
    @Published private(set) var screenshots: [ClipboardScreenshot] = []

    private var lastChangeCount: Int = -1
    private var awaitingImageData = false
    private var timer: Timer?
    private let maxCount = 6
    private let imageTypes: [NSPasteboard.PasteboardType] = [
        .png,
        .tiff,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.jpeg-openxml")
    ]

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        pollPasteboard()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func pollNow() {
        pollPasteboard()
    }

    /// Returns true if the image was already in the clipboard.
    func copyBack(_ shot: ClipboardScreenshot) -> Bool {
        let pb = NSPasteboard.general
        if let type = pb.availableType(from: imageTypes),
           let data = pb.data(forType: type),
           Self.fingerprint(for: data) == shot.fingerprint {
            return true
        }

        pb.clearContents()
        pb.setData(shot.payload, forType: shot.payloadType)
        lastChangeCount = pb.changeCount
        awaitingImageData = false
        return false
    }

    private func pollPasteboard() {
        let pb = NSPasteboard.general
        let changeCount = pb.changeCount
        if changeCount == lastChangeCount && !awaitingImageData {
            return
        }

        if let capture = Self.readImage(from: pb) {
            lastChangeCount = changeCount
            awaitingImageData = false
            ingest(capture)
            return
        }

        if Self.looksLikeImage(pb) {
            lastChangeCount = changeCount
            awaitingImageData = true
            return
        }

        lastChangeCount = changeCount
        awaitingImageData = false
    }

    private func ingest(_ capture: (data: Data, type: NSPasteboard.PasteboardType, cg: CGImage)) {
        guard capture.cg.width >= 200, capture.cg.height >= 100 else { return }
        let fingerprint = Self.fingerprint(for: capture.data)
        guard !screenshots.contains(where: { $0.fingerprint == fingerprint }) else { return }

        let shot = ClipboardScreenshot(
            id: UUID(),
            fingerprint: fingerprint,
            thumbnail: Self.makeThumbnail(from: capture.cg),
            payload: capture.data,
            payloadType: capture.type
        )
        screenshots.insert(shot, at: 0)
        if screenshots.count > maxCount {
            screenshots.removeLast()
        }
    }

    private static func readImage(from pb: NSPasteboard) -> (data: Data, type: NSPasteboard.PasteboardType, cg: CGImage)? {
        for type in [
            NSPasteboard.PasteboardType.png,
            NSPasteboard.PasteboardType.tiff,
            NSPasteboard.PasteboardType("public.jpeg")
        ] {
            if let data = pb.data(forType: type),
               let parsed = parseImage(data: data, type: type) {
                return parsed
            }
        }

        if let image = NSImage(pasteboard: pb),
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let data = image.tiffRepresentation ?? Data()
            guard !data.isEmpty else { return nil }
            return (data, .tiff, cg)
        }

        return nil
    }

    private static func parseImage(data: Data, type: NSPasteboard.PasteboardType) -> (data: Data, type: NSPasteboard.PasteboardType, cg: CGImage)? {
        guard let image = NSImage(data: data),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return (data, type, cg)
    }

    private static func looksLikeImage(_ pb: NSPasteboard) -> Bool {
        let markers = ["png", "tiff", "jpeg", "jpg", "gif", "heic", "image", "file-url", "screenshot", "pict"]
        return (pb.types ?? []).contains { type in
            let raw = type.rawValue.lowercased()
            return markers.contains { raw.contains($0) }
        }
    }

    private static func fingerprint(for data: Data) -> UInt64 {
        var hasher = Insecure.MD5()
        hasher.update(data: withUnsafeBytes(of: UInt64(data.count)) { Data($0) })
        hasher.update(data: data.prefix(4096))
        if data.count > 4096 {
            hasher.update(data: data.suffix(4096))
        }
        let digest = hasher.finalize()
        return digest.withUnsafeBytes { ptr in
            ptr.load(as: UInt64.self)
        }
    }

    private static func makeThumbnail(from cg: CGImage) -> NSImage {
        let maxW = 168.0
        let maxH = 104.0
        let scale = min(maxW / Double(cg.width), maxH / Double(cg.height), 1)
        let width = max(1, Int((Double(cg.width) * scale).rounded()))
        let height = max(1, Int((Double(cg.height) * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
        }

        context.interpolationQuality = .low
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        let out = context.makeImage() ?? cg
        return NSImage(cgImage: out, size: NSSize(width: width, height: height))
    }
}
