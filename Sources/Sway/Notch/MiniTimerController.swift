import SwiftUI

struct MiniTimerView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @AppStorage("workDuration") private var workDuration: Double = 25
    @AppStorage("theme") private var theme: String = "dark"
    let cornerRadius: CGFloat
    let width: CGFloat

    var body: some View {
        Text(viewModel.formattedTime)
            .font(.custom("Forza Thin", size: 14))
            .foregroundColor(ThemeColors.text(theme))
            .monospacedDigit()
            .frame(width: width - 14, alignment: .leading)
            .frame(maxHeight: .infinity)
            .padding(.leading, 14)
            .background(
                BottomRoundedRect(radius: cornerRadius).fill(ThemeColors.background(theme))
            )
            .frame(width: width)
    }
}

struct CoffeeIconView: View {
    @AppStorage("theme") private var theme: String = "dark"
    let cornerRadius: CGFloat

    var body: some View {
        Image(systemName: "cup.and.saucer.fill")
            .font(.system(size: 13))
            .foregroundColor(.orange.opacity(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                BottomRoundedRect(radius: cornerRadius).fill(ThemeColors.background(theme))
            )
    }
}

struct FocusIconView: View {
    @AppStorage("theme") private var theme: String = "dark"
    @ObservedObject var musicViewModel: MusicViewModel
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if musicViewModel.currentTrack.isPlaying,
               let url = musicViewModel.currentTrack.albumArtURL,
               let nsImage = NSImage(contentsOf: url)
            {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(x: -2)
        .background(
            BottomRoundedRect(radius: cornerRadius).fill(ThemeColors.background(theme))
        )
    }
}
