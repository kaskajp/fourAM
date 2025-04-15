import Foundation
import ServiceManagement

/// Manages the app's launch at login functionality
struct LaunchAtLoginManager {
    private static let bundleIdentifier = Bundle.main.bundleIdentifier!
    
    /// Set whether the app should launch at login
    /// - Parameter enabled: true to enable launch at login, false to disable
    static func setLaunchAtLogin(enabled: Bool) {
        // Use SMAppService for macOS 13+ (Ventura and later)
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                    try service.register()
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
                print("Successfully \(enabled ? "registered" : "unregistered") app for launch at login")
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") app for launch at login: \(error.localizedDescription)")
            }
        } else {
            // For macOS 12 and earlier
            // Use SMLoginItemSetEnabled instead of LSSharedFileList for compatibility
            let success = SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled)
            if success {
                print("Successfully \(enabled ? "registered" : "unregistered") app for launch at login")
            } else {
                print("Failed to \(enabled ? "register" : "unregister") app for launch at login")
            }
        }
    }
    
    /// Check if the app is configured to launch at login
    /// - Returns: true if the app is configured to launch at login, false otherwise
    static func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // For older macOS versions, there's no direct way to check
            // Just use the AppStorage value maintained in the UI
            return UserDefaults.standard.bool(forKey: "autoLaunch")
        }
    }
} 