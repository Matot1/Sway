import Cocoa
import SwiftUI
import Combine

class SettingsWindowController: NSWindowController {
    private var cancellables = Set<AnyCancellable>()
    let navigation = SettingsNavigation()

    static func create() -> SettingsWindowController {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = tr("Settings")
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(white: 0.12, alpha: 1)
        window.center()

        let controller = SettingsWindowController(window: window)
        let hostingView = NSHostingView(rootView: SettingsView(navigation: controller.navigation))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        window.contentView = hostingView

        controller.observeLanguageChanges()
        return controller
    }

    private func observeLanguageChanges() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.window?.title = tr("Settings")
            }
            .store(in: &cancellables)
    }

    func show(tab: SettingsTab? = nil) {
        if let tab {
            navigation.selectedTab = tab
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
