import SwiftUI
import SwiftData
import AppKit

@main
struct fourAMApp: App {
    @ObservedObject var libraryViewModel = LibraryViewModel.shared
    @ObservedObject private var playbackManager = PlaybackManager.shared
    @FocusState private var isSearchFieldFocused: Bool
    
    private let appState = AppState.shared
    
    init() {
        // Force linking of TagLib symbols
        forceTagLibSymbolLinking()
        
        // Force linking of additional TagLib symbols
        let byteVector = taglib_bytevector_create()
        if byteVector != nil {
            _ = taglib_bytevector_data(byteVector)
            _ = taglib_bytevector_size(byteVector)
            taglib_bytevector_destroy(byteVector)
        }
        
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
            // Replace the default File menu commands
            CommandGroup(replacing: .newItem) {
                Button("Add Folder...") {
                    NotificationCenter.default.post(name: Notification.Name("MenuAddFolder"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("New Playlist") {
                    NotificationCenter.default.post(name: Notification.Name("MenuNewPlaylist"), object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
                
                Divider()
                
                // Add back the standard Close command
                Button("Close Window") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
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
