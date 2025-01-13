//
//  fourAMApp.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import SwiftUI
import SwiftData

@main
struct fourAMApp: App {
    @ObservedObject var libraryViewModel = LibraryViewModel.shared
    @ObservedObject private var playbackManager = PlaybackManager.shared
    private let globalKeyEventHandler = GlobalKeyEventHandler()
    
    init() {
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            print("App Support Path: \(appSupportURL.path)")
        } else {
            print("No Application Support directory found.")
        }
        
        // Initialize global key event handler
        globalKeyEventHandler.setup(playbackManager: playbackManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryViewModel) // Provide ViewModel to ContentView
                .modelContainer(for: [Track.self])
        }
        
        // Add the settings scene
        Settings {
            SettingsWrapper()
                .environmentObject(libraryViewModel)
                .modelContainer(for: [Track.self])
        }
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent, playbackManager: PlaybackManager) -> NSEvent? {
        if event.characters == " " {
            if playbackManager.isPlaying {
                playbackManager.pause()
            } else {
                playbackManager.resume()
            }
            return nil // Swallow the event
        }
        return event // Pass the event to the system
    }
}

// Wrapper to ensure tabs render correctly in Settings
struct SettingsWrapper: View {
    var body: some View {
        SettingsView()
            .frame(minWidth: 500, minHeight: 400)
    }
}
