import Foundation
import AppKit
import Carbon.HIToolbox
import Combine

struct HotkeyConfiguration: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    static let defaultVoiceHotkey = HotkeyConfiguration(
        keyCode: UInt16(kVK_ANSI_T),
        modifiers: [.command, .shift]
    )

    static let defaultMenuHotkey = HotkeyConfiguration(
        keyCode: UInt16(kVK_ANSI_M),
        modifiers: [.command, .shift]
    )

    var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }

        if let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        default: return nil
        }
    }
}

extension NSEvent.ModifierFlags: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

final class HotkeyService: ObservableObject {
    @Published var voiceHotkey: HotkeyConfiguration {
        didSet {
            saveConfiguration()
            updateMonitor()
        }
    }

    @Published var menuHotkey: HotkeyConfiguration {
        didSet {
            saveConfiguration()
            updateMonitor()
        }
    }

    @Published private(set) var isListening: Bool = false
    @Published var isRecordingNewHotkey: Bool = false

    var onVoiceHotkeyPressed: (() -> Void)?
    var onMenuHotkeyPressed: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init() {
        voiceHotkey = Self.loadConfiguration()
        menuHotkey = Self.loadMenuConfiguration()
    }

    deinit {
        stopListening()
    }

    // MARK: - Monitor Management

    func startListening() {
        guard !isListening else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }

        isListening = true
        print("Hotkey listening started: \(voiceHotkey.displayString)")
    }

    func stopListening() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        isListening = false
    }

    private func updateMonitor() {
        if isListening {
            stopListening()
            startListening()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Check voice hotkey (Cmd+Shift+T)
        if event.keyCode == voiceHotkey.keyCode &&
           modifiers == voiceHotkey.modifiers.intersection(.deviceIndependentFlagsMask) {
            DispatchQueue.main.async { [weak self] in
                self?.onVoiceHotkeyPressed?()
            }
        }

        // Check menu hotkey (Cmd+Shift+M)
        if event.keyCode == menuHotkey.keyCode &&
           modifiers == menuHotkey.modifiers.intersection(.deviceIndependentFlagsMask) {
            DispatchQueue.main.async { [weak self] in
                self?.onMenuHotkeyPressed?()
            }
        }
    }

    // MARK: - Persistence

    private static let configKey = "HotkeyConfiguration"
    private static let menuConfigKey = "MenuHotkeyConfiguration"

    private static func loadConfiguration() -> HotkeyConfiguration {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(HotkeyConfiguration.self, from: data) else {
            return .defaultVoiceHotkey
        }
        return config
    }

    private static func loadMenuConfiguration() -> HotkeyConfiguration {
        guard let data = UserDefaults.standard.data(forKey: menuConfigKey),
              let config = try? JSONDecoder().decode(HotkeyConfiguration.self, from: data) else {
            return .defaultMenuHotkey
        }
        return config
    }

    private func saveConfiguration() {
        if let voiceData = try? JSONEncoder().encode(voiceHotkey) {
            UserDefaults.standard.set(voiceData, forKey: Self.configKey)
        }
        if let menuData = try? JSONEncoder().encode(menuHotkey) {
            UserDefaults.standard.set(menuData, forKey: Self.menuConfigKey)
        }
    }
}

// MARK: - Hotkey Recording
extension HotkeyService {
    func startRecordingHotkey(completion: @escaping (HotkeyConfiguration?) -> Void) {
        isRecordingNewHotkey = true

        // Temporarily replace monitor to capture new hotkey
        stopListening()

        var recordMonitor: Any?
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Require at least one modifier
            guard !modifiers.isEmpty else { return event }

            let newConfig = HotkeyConfiguration(keyCode: event.keyCode, modifiers: modifiers)

            DispatchQueue.main.async {
                self.isRecordingNewHotkey = false
                if let monitor = recordMonitor {
                    NSEvent.removeMonitor(monitor)
                }
                self.startListening()
                completion(newConfig)
            }

            return nil // Consume the event
        }
    }

    func cancelRecordingHotkey() {
        isRecordingNewHotkey = false
        startListening()
    }
}
