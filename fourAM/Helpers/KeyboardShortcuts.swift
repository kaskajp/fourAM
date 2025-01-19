import AppKit

class KeyMonitorManager: ObservableObject {
    private var monitor: Any?

    func startMonitoring(isSearchFieldFocused: @escaping () -> Bool) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
}
