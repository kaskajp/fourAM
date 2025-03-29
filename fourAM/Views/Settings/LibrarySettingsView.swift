import SwiftUI
import SwiftData

struct LibrarySettingsView: View {
    @AppStorage("defaultLibraryPath") private var defaultLibraryPath: String = ""
    @Environment(\.modelContext) private var modelContext // Access SwiftData context
    
    @State private var libraryActor: LibraryModelActor
    @State private var showAlert = false // Controls the alert for confirmation
    @State private var isClearing = false
    @State private var showThumbnailCacheAlert = false
    @State private var isClearingThumbnails = false
    @State private var showRegenerateAlert = false
    @State private var isRegenerating = false
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel // Access ViewModel globally
    
    init(modelContext: ModelContext) {
        // Initialize the actor with the model context's container configuration
        let container = modelContext.container
        guard let configuration = container.configurations.first else {
            fatalError("No model configuration found")
        }
        self.libraryActor = LibraryModelActor(modelDescriptor: configuration)
    }

    var body: some View {
        ZStack {
            VStack {
                if isClearing {
                    ProgressView("Clearing Library...")
                        .padding()
                } else {
                    Form {
                        /*HStack {
                            TextField("Default Library Path", text: $defaultLibraryPath)
                            Button("Browse...") {
                                chooseFolder()
                            }
                        }*/

                        // Clear Library Button
                        Section {
                            Button(role: .destructive) {
                                showAlert = true // Trigger the alert
                            } label: {
                                Text("Clear Library")
                            }
                        }
                        
                        // Clear Thumbnail Cache Button
                        Section {
                            Button(role: .destructive) {
                                showThumbnailCacheAlert = true
                            } label: {
                                Text("Clear Thumbnail Cache")
                            }
                            
                            Button {
                                showRegenerateAlert = true
                            } label: {
                                Text("Regenerate Album Art")
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
            .alert("Clear Thumbnail Cache", isPresented: $showThumbnailCacheAlert) {
                Button("Clear", role: .destructive, action: clearThumbnailCache)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to clear the thumbnail cache? This will require thumbnails to be regenerated when viewing albums.")
            }
            .alert("Regenerate Album Art", isPresented: $showRegenerateAlert) {
                Button("Regenerate", action: regenerateAlbumArt)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will regenerate all album art thumbnails. This may take a few moments.")
            }
            
            if isRegenerating {
                Color(.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.0)
                    Text("Regenerating Album Art...")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
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
                await MainActor.run {
                    self.libraryViewModel.tracks = remainingTracks
                    self.isClearing = false
                    print("Library cleared successfully.")
                }
            } catch {
                await MainActor.run {
                    self.isClearing = false
                    print("Failed to clear library: \(error)")
                }
            }
        }
    }

    private func clearThumbnailCache() {
        isClearingThumbnails = true
        Task {
            // Clear file system cache
            await ThumbnailCache.shared.clearCache()
            
            // Clear SwiftData thumbnails
            for track in libraryViewModel.tracks {
                track.thumbnail = nil
            }
            
            // Save changes to SwiftData
            try? modelContext.save()
            
            // Refresh the tracks to update the UI
            libraryViewModel.refreshTracks(context: modelContext)
            
            await MainActor.run {
                self.isClearingThumbnails = false
                print("Thumbnail cache cleared successfully.")
            }
        }
    }

    private func regenerateAlbumArt() {
        isRegenerating = true
        Task {
            await libraryViewModel.regenerateAlbumArt(context: modelContext)
            await MainActor.run {
                self.isRegenerating = false
                print("Album art regenerated successfully.")
            }
        }
    }
}
