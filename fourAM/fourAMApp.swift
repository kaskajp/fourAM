import SwiftUI
import SwiftData

@main
struct fourAMApp: App {
    @ObservedObject var libraryViewModel = LibraryViewModel.shared
    @ObservedObject private var playbackManager = PlaybackManager.shared
    @FocusState private var isSearchFieldFocused: Bool
    
    private let appState = AppState.shared
    
    init() {
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            print("App Support Path: \(appSupportURL.path)")
        } else {
            print("No Application Support directory found.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryViewModel) // Provide ViewModel to ContentView
                .modelContainer(for: [Track.self])
                .frame(minWidth: 800, minHeight: 400)
        }
        .commands {
            CommandGroup(replacing: CommandGroupPlacement.appInfo) {
                Button("About 4AM") {
                    showAboutWindow()
                }
            }
        }
        
        // Add the settings scene
        Settings {
            SettingsWrapper()
                .environmentObject(libraryViewModel)
                .modelContainer(for: [Track.self])
        }
    }
    
    func showAboutWindow() {
            if appState.aboutWindow == nil { // Ensure the window is created only once
                appState.aboutWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                    styleMask: [.titled, .closable],
                    backing: .buffered, defer: false
                )
                appState.aboutWindow?.center()
                appState.aboutWindow?.title = "About 4AM"
                appState.aboutWindow?.contentView = NSHostingView(rootView: AboutView())
                appState.aboutWindow?.isReleasedWhenClosed = false // Prevent deallocation when closed
            }

            appState.aboutWindow?.makeKeyAndOrderFront(nil)
        }
}

// Wrapper to ensure tabs render correctly in Settings
struct SettingsWrapper: View {
    var body: some View {
        SettingsView()
            .frame(minWidth: 500, minHeight: 400)
    }
}
