import Foundation
import AppKit
import Combine

struct WindowInfo: Equatable {
    let appName: String
    let appBundleId: String?
    let windowTitle: String?
    let url: String?

    static let idle = WindowInfo(appName: "Idle", appBundleId: nil, windowTitle: nil, url: nil)
}

final class WindowTracker: ObservableObject {
    @Published private(set) var currentWindow: WindowInfo = .idle
    @Published private(set) var isAccessibilityEnabled: Bool = false

    private var timer: Timer?
    private let trackingInterval: TimeInterval = 2.0

    init() {
        checkAccessibilityPermission()
    }

    // MARK: - Permissions

    @discardableResult
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("🔐 Accessibility check: \(trusted ? "GRANTED ✅" : "DENIED ❌")")

        DispatchQueue.main.async {
            self.isAccessibilityEnabled = trusted
        }
        return trusted
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Tracking

    func startTracking() {
        let hasPermission = checkAccessibilityPermission()
        print("🚀 Starting tracking (permission: \(hasPermission ? "YES" : "NO"))")

        if !hasPermission {
            requestAccessibilityPermission()
        }

        stopTracking()

        // Always start timer - will try to capture regardless
        timer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            self?.captureCurrentWindow()
        }
        timer?.tolerance = 0.5

        // Capture immediately
        captureCurrentWindow()
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    private func captureCurrentWindow() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("📱 No frontmost app")
            currentWindow = .idle
            return
        }

        let appName = frontmostApp.localizedName ?? "Unknown"
        let bundleId = frontmostApp.bundleIdentifier

        // Get window title via Accessibility API (may fail without permission)
        let windowTitle = getWindowTitle(for: frontmostApp)

        // Extract URL if it's a browser
        let url = extractURLIfBrowser(bundleId: bundleId, windowTitle: windowTitle)

        let newWindow = WindowInfo(
            appName: appName,
            appBundleId: bundleId,
            windowTitle: windowTitle,
            url: url
        )

        if newWindow != currentWindow {
            print("📱 Window changed: \(appName) - \(windowTitle ?? "no title")")
            DispatchQueue.main.async {
                self.currentWindow = newWindow
            }
        }
    }

    private func getWindowTitle(for app: NSRunningApplication) -> String? {
        // Try Accessibility API first (needs Accessibility permission)
        if let title = getWindowTitleViaAccessibility(for: app) {
            return title
        }

        // Try AppleScript (needs Automation permission)
        if let title = getWindowTitleViaAppleScript() {
            return title
        }

        // Fallback: Use CGWindowList (no permission needed but limited info)
        return getWindowTitleViaCGWindow(for: app)
    }

    private func getWindowTitleViaCGWindow(for app: NSRunningApplication) -> String? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let pid = app.processIdentifier

        for window in windowList {
            if let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
               ownerPID == pid,
               let title = window[kCGWindowName as String] as? String,
               !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private func getWindowTitleViaAccessibility(for app: NSRunningApplication) -> String? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        var focusedWindow: AnyObject?

        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success, let windowElement = focusedWindow else {
            return nil
        }

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            windowElement as! AXUIElement,
            kAXTitleAttribute as CFString,
            &title
        )

        if titleResult == .success, let windowTitle = title as? String {
            return windowTitle
        }

        return nil
    }

    private func getWindowTitleViaAppleScript() -> String? {
        let script = """
            tell application "System Events"
                set frontApp to first process whose frontmost is true
                if (count of windows of frontApp) > 0 then
                    return name of first window of frontApp
                end if
            end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if let err = error {
                print("⚠️ AppleScript error: \(err)")
                return nil
            }
            if let title = result.stringValue {
                return title
            }
        }
        return nil
    }

    private func extractURLIfBrowser(bundleId: String?, windowTitle: String?) -> String? {
        guard let bundleId = bundleId else { return nil }

        let browserBundleIds = [
            "com.apple.Safari",
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "company.thebrowser.Browser", // Arc
            "com.brave.Browser",
            "com.operasoftware.Opera"
        ]

        guard browserBundleIds.contains(bundleId) else { return nil }

        // Try to extract URL using AppleScript (Safari) or Accessibility API
        return extractURLFromBrowser(bundleId: bundleId)
    }

    private func extractURLFromBrowser(bundleId: String) -> String? {
        var script: String

        switch bundleId {
        case "com.apple.Safari":
            script = """
                tell application "Safari"
                    if (count of windows) > 0 then
                        return URL of current tab of front window
                    end if
                end tell
            """
        case "com.google.Chrome":
            script = """
                tell application "Google Chrome"
                    if (count of windows) > 0 then
                        return URL of active tab of front window
                    end if
                end tell
            """
        case "company.thebrowser.Browser": // Arc
            script = """
                tell application "Arc"
                    if (count of windows) > 0 then
                        return URL of active tab of front window
                    end if
                end tell
            """
        case "org.mozilla.firefox":
            // Firefox doesn't support AppleScript well, try to extract from title
            return nil
        default:
            return nil
        }

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                return result.stringValue
            }
        }

        return nil
    }
}
