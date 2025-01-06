//
//  SettingsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            LibrarySettingsView()
                .tabItem {
                    Label("Library", systemImage: "folder")
                }
            
            OutputSettingsView()
                .tabItem {
                    Label("Output", systemImage: "speaker.wave.2")
                }
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
        }
        .frame(width: 500, height: 400) // Adjust the size of the settings window
    }
}
