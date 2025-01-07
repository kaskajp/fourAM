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
    @StateObject private var libraryViewModel = LibraryViewModel() // Shared ViewModel
    
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
        }
        
        // Add the settings scene
        Settings {
            SettingsWrapper()
                .environmentObject(libraryViewModel)
                .modelContainer(for: [Track.self])
        }
    }
}

// Wrapper to ensure tabs render correctly in Settings
struct SettingsWrapper: View {
    var body: some View {
        SettingsView()
            .frame(minWidth: 500, minHeight: 400)
    }
}
