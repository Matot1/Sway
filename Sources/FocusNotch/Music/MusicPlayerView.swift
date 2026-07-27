import SwiftUI

struct MusicPlayerView: View {
    @ObservedObject var viewModel: MusicViewModel
    @ObservedObject var loc = LanguageManager.shared
    @AppStorage("theme") private var theme: String = "dark"
    @State private var dominantColor: Color? = nil

    private var isDarkBg: Bool {
        guard let c = dominantColor else { return theme != "light" && theme != "monochrome" }
        let uiC = NSColor(c)
        let lum = 0.299 * uiC.redComponent + 0.587 * uiC.greenComponent + 0.114 * uiC.blueComponent
        return lum < 0.5
    }

    var body: some View {
        HStack(spacing: 12) {
            albumArt

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(viewModel.currentTrack.artist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDarkBg ? .white : .black)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                HStack {
                    Text(viewModel.currentTrack.title)
                        .font(.system(size: 11))
                        .foregroundColor(isDarkBg ? .white.opacity(0.5) : .black.opacity(0.4))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                Button(action: viewModel.previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkBg ? .white : .black)
                }
                .buttonStyle(.plain)

                Button(action: viewModel.playPause) {
                    Image(systemName: viewModel.currentTrack.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isDarkBg ? .white : .black)
                }
                .buttonStyle(.plain)

                Button(action: viewModel.nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkBg ? .white : .black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Group {
                if let c = dominantColor {
                    c.opacity(0.85)
                } else {
                    Color.clear
                }
            }
        )
        .animation(.easeInOut(duration: 0.3), value: dominantColor?.description)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: viewModel.currentTrack.albumArtURL) { _, url in
            extractColor(from: url)
        }
        .onAppear {
            extractColor(from: viewModel.currentTrack.albumArtURL)
        }
    }

    private func extractColor(from url: URL?) {
        guard let url = url, let nsImage = NSImage(contentsOf: url) else {
            dominantColor = nil
            return
        }
        DispatchQueue.global(qos: .background).async {
            let color = nsImage.dominantColor()
            DispatchQueue.main.async {
                dominantColor = color
            }
        }
    }

    @ViewBuilder
    private var albumArt: some View {
        if let url = viewModel.currentTrack.albumArtURL,
           let nsImage = NSImage(contentsOf: url)
        {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.1))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.3))
                )
        }
    }
}

extension NSImage {
    func dominantColor() -> Color? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = 32, h = 32
        guard let context = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            r += UInt64(pixels[i])
            g += UInt64(pixels[i + 1])
            b += UInt64(pixels[i + 2])
        }
        let total = UInt64(w * h)
        return Color(
            red: Double(r / total) / 255,
            green: Double(g / total) / 255,
            blue: Double(b / total) / 255
        )
    }
}
