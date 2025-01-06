//
//  LibrarySettingsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct LibrarySettingsView: View {
    @AppStorage("defaultLibraryPath") private var defaultLibraryPath: String = ""

    var body: some View {
        Form {
            HStack {
                TextField("Default Library Path", text: $defaultLibraryPath)
                Button("Browse...") {
                    chooseFolder()
                }
            }
        }
        .padding()
        .navigationTitle("Library")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedPath = panel.url?.path {
            defaultLibraryPath = selectedPath
        }
    }
}
