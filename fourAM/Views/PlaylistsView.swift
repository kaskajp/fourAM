import SwiftUI
import SwiftData
import AppKit

struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]
    @State private var showNewPlaylistSheet = false
    @State private var selectedPlaylist: Playlist? = nil
    
    var body: some View {
        List(selection: $selectedPlaylist) {
            ForEach(playlists) { playlist in
                NavigationLink(value: playlist) {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundColor(.indigo)
                        VStack(alignment: .leading) {
                            Text(playlist.name)
                            Text("\(playlist.tracks.count) tracks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        modelContext.delete(playlist)
                        try? modelContext.save()
                    } label: {
                        Label("Delete Playlist", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewPlaylistSheet = true
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewPlaylistSheet) {
            NewPlaylistSheet(track: nil)
        }
    }
}

struct NewPlaylistSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let track: Track?
    @State private var playlistName = ""
    @FocusState private var isNameFieldFocused: Bool
    
    private var isValidName: Bool {
        !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        Form {
            TextField("Playlist Name", text: $playlistName)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.leading)
                .focused($isNameFieldFocused)
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        print("Starting playlist creation...")
                        
                        // Trim whitespace from the name
                        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let playlist = Playlist(name: trimmedName)
                        print("Created playlist object: \(playlist.name)")
                        
                        if let track = track {
                            print("Adding track to playlist: \(track.title)")
                            playlist.addTrack(track)
                        }
                        
                        print("Inserting playlist into model context")
                        await MainActor.run {
                            modelContext.insert(playlist)
                        }
                        
                        // Verify the playlist was inserted
                        print("Verifying playlist insertion...")
                        if let playlists = try? await MainActor.run(body: {
                            try modelContext.fetch(FetchDescriptor<Playlist>())
                        }) {
                            print("Found \(playlists.count) playlists in context")
                            for p in playlists {
                                print("- \(p.name)")
                            }
                        }
                        
                        do {
                            print("Attempting to save model context")
                            try await MainActor.run {
                                try modelContext.save()
                            }
                            print("Successfully saved playlist: \(trimmedName)")
                            
                            // Add a small delay to ensure the save is processed
                            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                            
                            // Try to fetch all playlists
                            let allPlaylists = try await MainActor.run {
                                try modelContext.fetch(FetchDescriptor<Playlist>())
                            }
                            print("All playlists in database: \(allPlaylists.count)")
                            for p in allPlaylists {
                                print("- \(p.name)")
                            }
                            
                            // Check what's in the database
                            let savedTracks = try await MainActor.run {
                                try modelContext.fetch(FetchDescriptor<Track>())
                            }
                            print("Current tracks in database: \(savedTracks.count)")
                        } catch {
                            print("Failed to save playlist: \(error)")
                            print("Error details: \(error.localizedDescription)")
                            let nsError = error as NSError
                            print("Error domain: \(nsError.domain)")
                            print("Error code: \(nsError.code)")
                            print("Error user info: \(nsError.userInfo)")
                            print("Error description: \(nsError.description)")
                            print("Error failure reason: \(nsError.localizedFailureReason ?? "none")")
                            print("Error recovery suggestion: \(nsError.localizedRecoverySuggestion ?? "none")")
                        }
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
                .disabled(!isValidName)
            }
        }
        .frame(minWidth: 300, minHeight: 80)
        .presentationDragIndicator(.visible)
        .presentationDetents([.height(80)])
        .presentationBackground(.windowBackground)
        .presentationContentInteraction(.resizes)
        .task {
            if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                window.title = "New Playlist"
            }
        }
        .onAppear {
            // Disable global hotkey when sheet appears
            PlaybackManager.shared.disableGlobalHotkey()
        }
        .onDisappear {
            // Re-enable global hotkey when sheet disappears
            PlaybackManager.shared.enableGlobalHotkey()
        }
    }
} 