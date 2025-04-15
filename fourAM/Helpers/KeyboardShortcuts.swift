import AppKit
import SwiftUI

class KeyMonitorManager: ObservableObject {
    static let shared = KeyMonitorManager()
    private var monitor: Any?
    private var isEnabled = true

    private init() {}

    func startMonitoring(isSearchFieldFocused: @escaping () -> Bool) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isEnabled else { return event }
            
            if isSearchFieldFocused() {
                return event // Allow system to handle the event if search is focused
            }

            if event.characters == " " {
                if PlaybackManager.shared.isPlaying {
                    PlaybackManager.shared.pause()
                } else {
                    PlaybackManager.shared.resume()
                }
                return nil // Swallow the event
            }
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    func disableGlobalHotkey() {
        isEnabled = false
    }

    func enableGlobalHotkey() {
        isEnabled = true
    }
}
