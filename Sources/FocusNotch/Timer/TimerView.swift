import SwiftUI

struct TimerView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @ObservedObject var loc = LanguageManager.shared
    @AppStorage("workDuration") private var workDuration: Double = 25
    @AppStorage("theme") private var theme: String = "dark"

    var body: some View {
        HStack(spacing: 10) {
            Button(action: viewModel.reset) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ThemeColors.text(theme))
                    .frame(width: 30, height: 30)
                    .background(ThemeColors.background(theme))
                    .clipShape(Circle())
                    .opacity(viewModel.state == .idle ? 0.3 : 1)
            }
            .buttonStyle(.plain)

            Button(action: {
                if viewModel.isRunning {
                    viewModel.pause()
                } else {
                    viewModel.start()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(ThemeColors.accent(theme))
                    Circle()
                        .stroke(ThemeColors.text(theme).opacity(viewModel.isRunning ? 0.6 : 0), lineWidth: 2)
                        .padding(2)
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ThemeColors.text(theme))
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            ZStack {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        ThemeColors.progressBackground(theme)

                        ThemeColors.accentDim(theme)
                            .frame(width: geo.size.width * viewModel.progress)

                        Rectangle()
                            .fill(ThemeColors.accent(theme))
                            .frame(width: 1)
                            .offset(x: geo.size.width * viewModel.progress)
                    }
                }

                if viewModel.isOnBreak {
                    HStack(spacing: 6) {
                        Text(tr("Coffee break"))
                            .foregroundColor(theme == "light" || theme == "monochrome" ? Color(red: 0.8, green: 0.3, blue: 0) : .orange.opacity(0.8))
                        Text(viewModel.formattedTime)
                            .foregroundColor(ThemeColors.text(theme))
                            .monospacedDigit()
                    }
                    .font(.custom("Forza Thin", size: 22))
                } else {
                    Text(viewModel.formattedTime)
                        .font(.custom("Forza Thin", size: 22))
                        .foregroundColor(ThemeColors.text(theme))
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(viewModel.isOnBreak ? .orange : .clear, lineWidth: 1)
            )

            Button(action: {
                if !viewModel.isOnBreak {
                    viewModel.startBreak()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(ThemeColors.cardBackground(theme))
                    Circle()
                        .stroke(ThemeColors.text(theme).opacity(viewModel.isOnBreak ? 0.6 : 0), lineWidth: 2)
                        .padding(2)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11))
                        .foregroundColor(ThemeColors.text(theme))
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ThemeColors.stroke(theme), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
        .padding(.leading, 4)
    }
}
