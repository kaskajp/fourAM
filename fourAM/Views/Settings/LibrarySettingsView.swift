//
//  LibrarySettingsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI
import SwiftData

struct LibrarySettingsView: View {
    @AppStorage("defaultLibraryPath") private var defaultLibraryPath: String = ""
    @Environment(\.modelContext) private var modelContext // Access SwiftData context
    
    @State private var libraryActor: LibraryModelActor
    @State private var showAlert = false // Controls the alert for confirmation
    @State private var isClearing = false
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel // Access ViewModel globally
    
    init(modelContext: ModelContext) {
        self.libraryActor = LibraryModelActor(context: modelContext)
    }

    var body: some View {
        VStack {
            if isClearing {
                ProgressView("Clearing Library...")
                    .padding()
            } else {
                Form {
                    HStack {
                        TextField("Default Library Path", text: $defaultLibraryPath)
                        Button("Browse...") {
                            chooseFolder()
                        }
                    }

                    // Clear Library Button
                    Section {
                        Button(role: .destructive) {
                            showAlert = true // Trigger the alert
                        } label: {
                            Text("Clear Library")
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Library")
        .alert("Clear Library", isPresented: $showAlert) {
            Button("Clear", role: .destructive, action: clearLibrary) // Clear action
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the library? This action cannot be undone.")
        }
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

    private func clearLibrary() {
        isClearing = true
        Task {
            do {
                try await libraryActor.deleteAllTracks()
                let remainingTracks = try await libraryActor.fetchAllTracks()
                DispatchQueue.main.async {
                    self.libraryViewModel.tracks = remainingTracks
                    self.isClearing = false
                    print("Library cleared successfully.")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isClearing = false
                    print("Failed to clear library: \(error)")
                }
            }
        }
    }
}
