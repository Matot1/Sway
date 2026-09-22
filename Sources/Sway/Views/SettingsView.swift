import SwiftUI
import ServiceManagement

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case timer = "Timer"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .timer: return "timer"
        case .about: return "info.circle"
        }
    }
}

final class SettingsNavigation: ObservableObject {
    @Published var selectedTab: SettingsTab = .general
}

struct SettingsView: View {
    @ObservedObject var loc = LanguageManager.shared
    @ObservedObject var navigation: SettingsNavigation

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { navigation.selectedTab = tab }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11))
                            Text(tr(tab.rawValue))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(navigation.selectedTab == tab ? .white : .white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(navigation.selectedTab == tab ? Color.white.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(navigation.selectedTab == tab ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Group {
                switch navigation.selectedTab {
                case .general:
                    GeneralSettingsView()
                case .timer:
                    TimerSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }

            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text(tr("Quit Sway"))
                        .font(.system(size: 10))
                }
                .foregroundColor(.red.opacity(0.6))
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 480, height: 380)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject var loc = LanguageManager.shared
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("theme") private var theme: String = "dark"
    @AppStorage("musicProvider") private var musicProvider: String = MusicProvider.yandexMusic.storageKey
    @AppStorage("soundAlerts") private var soundAlerts = true

    private var themeKey: String {
        switch theme {
        case "light": return "Light"
        case "monochrome": return "Monochrome"
        default: return "Default"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                generalRow(icon: "bolt.circle", title: "Launch at Login") {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .tint(.orange)
                        .onChange(of: launchAtLogin) { _, newValue in
                            if newValue {
                                try? SMAppService.mainApp.register()
                            } else {
                                try? SMAppService.mainApp.unregister()
                            }
                        }
                }

                generalRow(icon: "music.note", title: "Music Integration") {
                    compactMenu(MusicProvider.fromStorageKey(musicProvider)?.rawValue ?? musicProvider) {
                        ForEach(MusicProvider.allCases, id: \.self) { provider in
                            Button(tr(provider.rawValue)) {
                                musicProvider = provider.storageKey
                            }
                        }
                    }
                }

                generalRow(icon: "globe", title: "Language") {
                    compactMenu(loc.language == "ru" ? "Russian" : "English") {
                        Button(tr("English")) { loc.setLanguage("en") }
                        Button(tr("Russian")) { loc.setLanguage("ru") }
                    }
                }

                generalRow(icon: "paintpalette", title: "Theme") {
                    compactMenu(themeKey) {
                        Button(tr("Default")) { theme = "dark" }
                        Button(tr("Light")) { theme = "light" }
                        Button(tr("Monochrome")) { theme = "monochrome" }
                    }
                }

                generalRow(icon: "bell", title: "Sound Alerts") {
                    Toggle("", isOn: $soundAlerts)
                        .toggleStyle(.switch)
                        .tint(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func generalRow<Trailing: View>(
        icon: String,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        ZStack {
            Toggle("", isOn: .constant(false))
                .toggleStyle(.switch)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20)

                Text(tr(title))
                    .font(.custom("Forza Thin", size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                trailing()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func compactMenu<Content: View>(_ titleKey: String, @ViewBuilder content: () -> Content) -> some View {
        Menu(content: content) {
            Text(tr(titleKey))
                .foregroundColor(.orange)
                .font(.custom("Forza Thin", size: 12))
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .fixedSize(horizontal: true, vertical: true)
        .frame(height: 16)
    }
}

// MARK: - Timer

struct TimerSettingsView: View {
    @ObservedObject var loc = LanguageManager.shared
    @AppStorage("workDuration") private var workDuration: Double = 25
    @AppStorage("longBreakDuration") private var longBreakDuration: Double = 5
    @AppStorage("extendedBreakDuration") private var extendedBreakDuration: Double = 45
    @AppStorage("sessionsBeforeLongBreak") private var sessionsBeforeLongBreak: Double = 4
    @AppStorage("autoStartBreak") private var autoStartBreak = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                DurationRow(icon: "clock", label: tr("Focus Duration"), value: $workDuration, range: 5...60, suffix: tr("min"))
                DurationRow(icon: "cup.and.saucer.fill", label: tr("Coffee Break Time"), value: $longBreakDuration, range: 1...45, suffix: tr("min"))
                DurationRow(icon: "moon.zzz.fill", label: tr("Long Break"), value: $extendedBreakDuration, range: 15...90, suffix: tr("min"))

                HStack(spacing: 10) {
                    Image(systemName: "repeat")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20)

                    Text(tr("Sessions before long break"))
                        .font(.custom("Forza Thin", size: 12))
                        .foregroundColor(.white)
                    Spacer()
                    Stepper(value: $sessionsBeforeLongBreak, in: 1...10) {
                        Text("\(Int(sessionsBeforeLongBreak))")
                            .font(.custom("Forza Thin", size: 12))
                            .foregroundColor(.white)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 10) {
                    Image(systemName: "forward")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 20)

                    Text(tr("Automatically start break after focus session"))
                        .font(.custom("Forza Thin", size: 12))
                        .foregroundColor(.white)

                    Spacer()

                    Toggle("", isOn: $autoStartBreak)
                        .toggleStyle(.switch)
                        .tint(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DurationRow: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 20)

                Text(label)
                    .font(.custom("Forza Thin", size: 12))
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(value)) \(suffix)")
                    .font(.custom("Forza Thin", size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            Slider(value: $value, in: range, step: 1)
                .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - About

struct AboutSettingsView: View {
    @ObservedObject var loc = LanguageManager.shared

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.7"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(tr("Sway"))
                    .font(.custom("Forza Thin", size: 18))
                    .foregroundColor(.white)

                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)

                Text(tr("Version") + " \(version)")
                    .font(.custom("Forza Thin", size: 11))
                    .foregroundColor(.white.opacity(0.4))

                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("CheckForUpdates"), object: nil)
                }) {
                    Text(tr("Check for Updates"))
                        .font(.custom("Forza Thin", size: 12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
                .padding(.top, 4)

                Text("Developer: Telegram — @Mato_o")
                    .font(.custom("Forza Thin", size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Shared Components

