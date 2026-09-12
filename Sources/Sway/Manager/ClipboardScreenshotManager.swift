import SwiftUI
import Combine

class ClipboardScreenshotManager: ObservableObject {
    @Published private(set) var screenshots: [NSImage] = []

    private var lastChangeCount: Int = 0
    private var timer: AnyCancellable?
    private let maxCount = 6

    init() {
        timer = Timer.publish(every: 0.4, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollPasteboard()
            }
    }

    private func pollPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let image = NSImage(pasteboard: pb), image.isScreenshotLike() else { return }
        guard !screenshots.contains(where: { $0.samePixels(as: image) }) else { return }

        screenshots.insert(image, at: 0)
        if screenshots.count > maxCount {
            screenshots.removeLast()
        }
    }

    /// Returns true if the image was already in the clipboard, false if it was copied now.
    func copyBack(_ image: NSImage) -> Bool {
        let pb = NSPasteboard.general
        if let existing = NSImage(pasteboard: pb), existing.samePixels(as: image) {
            return true
        }
        pb.clearContents()
        pb.writeObjects([image])
        return false
    }
}

extension NSImage {
    func isScreenshotLike() -> Bool {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        return cg.width >= 200 && cg.height >= 100
    }

    func pngData() -> Data? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .png, properties: [:])
    }

    func samePixels(as other: NSImage) -> Bool {
        guard let a = pngData(), let b = other.pngData() else { return false }
        return a == b
    }
}
