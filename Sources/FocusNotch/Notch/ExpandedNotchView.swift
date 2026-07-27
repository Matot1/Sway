import SwiftUI

struct ExpandedNotchView: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var loc = LanguageManager.shared
    @AppStorage("theme") private var theme: String = "dark"

    var body: some View {
        VStack(spacing: 4) {
            notchBar
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ThemeColors.background(theme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var notchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                tabButton(for: .timer)
                tabButton(for: .music)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: {
                    viewModel.collapseNotch()
                    NotificationCenter.default.post(name: NSNotification.Name("OpenFocusNotchSettings"), object: nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .semibold))
                        Text(tr("Settings"))
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(ThemeColors.secondaryText(theme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(for tab: NotchTab) -> some View {
        Button(action: {
            viewModel.selectedTab = tab
        }) {
            HStack(spacing: 4) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text(tr(tab.rawValue))
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                viewModel.selectedTab == tab
                    ? tab == .music && theme != "monochrome" ? Color.red : ThemeColors.accent(theme)
                    : Color.clear
            )
            .clipShape(Capsule())
            .foregroundColor(
                viewModel.selectedTab == tab
                    ? ThemeColors.text(theme)
                    : ThemeColors.secondaryText(theme)
            )
        }
        .buttonStyle(.plain)
    }

    private var tabContent: some View {
        Group {
            switch viewModel.selectedTab {
            case .timer:
                TimerView(viewModel: viewModel.pomodoroViewModel)
            case .music:
                MusicPlayerView(viewModel: viewModel.musicViewModel)
            case .settings:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .animation(.spring(response: 0.3), value: viewModel.selectedTab)
    }
}
