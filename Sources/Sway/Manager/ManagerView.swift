import SwiftUI

struct ManagerView: View {
    @ObservedObject var clipboardManager: ClipboardScreenshotManager
    @ObservedObject var loc = LanguageManager.shared
    @AppStorage("theme") private var theme: String = "dark"
    @State private var flashText: String?
    @State private var flashTask: DispatchWorkItem?

    var body: some View {
        ZStack {
            Group {
                if clipboardManager.screenshots.isEmpty {
                    Text(tr("No screenshots yet"))
                        .font(.custom("Forza Thin", size: 11))
                        .foregroundColor(ThemeColors.tertiaryText(theme))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(clipboardManager.screenshots.enumerated()), id: \.offset) { index, image in
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 84, height: 52)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(ThemeColors.stroke(theme), lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        handleTap(image)
                                    }
                                    .help(tr("Click to copy"))
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)

            if let text = flashText {
                Text(text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.75))
                    .clipShape(Capsule())
                    .transition(.opacity)
            }
        }
    }

    private func handleTap(_ image: NSImage) {
        let alreadyCopied = clipboardManager.copyBack(image)
        showFlash(alreadyCopied ? tr("Already Copy!") : tr("Copy!"))
    }

    private func showFlash(_ text: String) {
        flashTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            flashText = text
        }
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.5)) {
                flashText = nil
            }
        }
        flashTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: task)
    }
}
