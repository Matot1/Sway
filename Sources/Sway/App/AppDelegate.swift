import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        UserDefaults.standard.register(defaults: [
            "soundAlerts": true,
            "fullConcentration": false,
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettings),
            name: NSNotification.Name("OpenSwaySettings"),
            object: nil
        )

        DispatchQueue.main.async { [weak self] in
            self?.setupNotchWindow()
        }
    }

    private func setupNotchWindow() {
        notchWindowController = NotchWindowController.create()
        notchWindowController?.showWindow(nil)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController.create()
        }
        settingsWindowController?.show()
    }
}
