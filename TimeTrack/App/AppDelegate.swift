import Foundation
import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon since this is a menu bar app
        NSApp.setActivationPolicy(.accessory)

        print("TimeTrack application launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
        print("TimeTrack application terminating")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Don't reopen windows when clicking dock icon
        return false
    }
}

// MARK: - Launch at Login Helper
extension AppDelegate {
    static var launchAtLogin: Bool {
        get {
            UserDefaults.standard.bool(forKey: "LaunchAtLogin")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "LaunchAtLogin")
            updateLaunchAtLogin(newValue)
        }
    }

    private static func updateLaunchAtLogin(_ enabled: Bool) {
        #if DEBUG
        print("Launch at login: \(enabled) (not implemented in debug)")
        #else
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
        #endif
    }
}
