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
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                tabButton(for: .music)
                tabButton(for: .manager)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                tabButton(for: .timer)
                Button(action: {
                    viewModel.collapseNotch()
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSwaySettings"), object: nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .semibold))
                        Text(tr("Settings"))
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .foregroundColor(ThemeColors.secondaryText(theme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                viewModel.selectedTab == tab
                    ? tabBackground(tab)
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

    private func tabBackground(_ tab: NotchTab) -> Color {
        if tab == .music && theme != "monochrome" {
            return Color.red
        }
        if tab == .manager && theme != "monochrome" {
            return Color(red: 0.55, green: 0.45, blue: 0.15)
        }
        return ThemeColors.accent(theme)
    }

    private var tabContent: some View {
        Group {
            switch viewModel.selectedTab {
            case .timer:
                TimerView(viewModel: viewModel.pomodoroViewModel)
            case .music:
                MusicPlayerView(viewModel: viewModel.musicViewModel)
            case .manager:
                ManagerView(clipboardManager: viewModel.clipboardManager)
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
