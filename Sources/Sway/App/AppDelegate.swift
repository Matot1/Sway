import Cocoa
import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var updaterController: SPUStandardUpdaterController?

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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(checkForUpdates),
            name: NSNotification.Name("CheckForUpdates"),
            object: nil
        )

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        DispatchQueue.main.async { [weak self] in
            self?.setupNotchWindow()
        }
    }

    @objc private func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
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
