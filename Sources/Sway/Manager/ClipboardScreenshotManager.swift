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
    private var timer: Timer?
    private let maxCount = 6
    private let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        timer.tolerance = 0.5
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
        return false
    }

    private func pollPasteboard() {
        let pb = NSPasteboard.general
        let changeCount = pb.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let type = pb.availableType(from: imageTypes),
              let data = pb.data(forType: type) else { return }

        let fingerprint = Self.fingerprint(for: data)
        guard !screenshots.contains(where: { $0.fingerprint == fingerprint }) else { return }
        guard let image = NSImage(data: data),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cg.width >= 200, cg.height >= 100 else { return }

        let shot = ClipboardScreenshot(
            id: UUID(),
            fingerprint: fingerprint,
            thumbnail: Self.makeThumbnail(from: cg),
            payload: data,
            payloadType: type
        )
        screenshots.insert(shot, at: 0)
        if screenshots.count > maxCount {
            screenshots.removeLast()
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
