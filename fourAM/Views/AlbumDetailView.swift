import SwiftUI
import AppKit
import SwiftData

struct AlbumDetailView: View {
    let album: Album
    let onBack: () -> Void // Closure to handle the back button action

    @Environment(\.modelContext) var modelContext
    @ObservedObject var libraryViewModel: LibraryViewModel
    @ObservedObject private var keyMonitorManager = KeyMonitorManager.shared
    @FocusState private var isSearchFieldFocused: Bool
    @Environment(\.dismiss) var dismiss // Replace presentationMode with dismiss
    @State private var searchText: String = "" // To manage the search input
    @State private var selectedTrack: Track? = nil
    @State private var playTask: Task<Void, Never>?
    @State private var showNewPlaylistSheet = false
    @State private var trackToAddToNewPlaylist: Track? = nil
    
    var body: some View {
        // Group and sort tracks
        let filteredTracks = album.tracks.filter { track in
            searchText.isEmpty || track.title.lowercased().contains(searchText.lowercased())
        }
        let filteredGroupedTracks = Dictionary(grouping: filteredTracks) { $0.discNumber }
        let filteredSortedDiscs = filteredGroupedTracks.keys.sorted()

        return VStack(alignment: .leading) {
            // Top bar
            HStack(alignment: .center) {
                Button(action: onBack) { // Call the provided back action
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray) // Set the color of the icon
                    TextField("Filter tracks", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle()) // Use a plain style for better integration
                        .frame(maxWidth: 200)
                        .focused($isSearchFieldFocused)
                }
                .padding(8) // Add padding around the field
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2)) // Light gray background
                )
            }
            .padding(.bottom, 10)
            .zIndex(1)

            // Album header (cover + album title)
            HStack(spacing: 8) {
                if let data = album.thumbnail,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 180)
                        .cornerRadius(4)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 180, height: 180)
                        .cornerRadius(4)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(album.name)
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("\(album.albumArtist)")
                    .padding(.bottom, 10)
                    HStack(spacing: 4) {
                        Text("\(String(format: "%d", album.releaseYear))")
                        Text("·")
                        Text("\(album.genre)")
                        Text("·")
                        Text("\(album.totalTracks) tracks")
                    }
                    .padding(.bottom, 10)
                    Button(action: {
                        playFirstTrack()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.headline)
                            Text("Play")
                                .font(.headline)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .foregroundColor(.white)
                        .background(.indigo)
                        .cornerRadius(50)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
            .padding(.bottom, 8)
            .padding(.horizontal, 8)

            // Track list grouped by disc
            List {
                ForEach(filteredSortedDiscs, id: \.self) { disc in
                    Group {
                        if filteredGroupedTracks.keys.count > 1 {
                            // Custom header to avoid sticky behavior and darker background
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Disc \(disc)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 16) // Adjust header spacing
                            }
                            .background(Color.clear) // Ensure no background
                            .padding(.horizontal, 8) // Match content padding

                            // Tracks for the current disc
                            trackList(for: disc, tracks: filteredGroupedTracks[disc]!)
                        } else {
                            // For single-disc albums
                            trackList(for: disc, tracks: filteredGroupedTracks[disc]!)
                        }
                    }
                    .padding(0)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .listStyle(.plain) // Removes additional styling applied by default
            .listRowInsets(EdgeInsets()) // Removes default insets for each row
            .padding(.horizontal, 0) // Ensures the List aligns with the artwork and other content
            .frame(maxWidth: .infinity) // Expands the List to fill available space
        }
        .padding()
        .navigationTitle(album.name)
        .onAppear {
            keyMonitorManager.startMonitoring { isSearchFieldFocused }
        }
        .onDisappear {
            keyMonitorManager.stopMonitoring()
            playTask?.cancel()
        }
    }
    
    private func formatPlaytime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    
    @ViewBuilder
    private func trackList(for disc: Int, tracks: [Track]) -> some View {
        ForEach(tracks.sorted(by: { lhs, rhs in
            lhs.trackNumber < rhs.trackNumber
        }), id: \.id) { track in
            HStack {
                // Track number on the left
                Text("\(track.trackNumber)")
                    .frame(width: 30, alignment: .leading)

                // Track title in the center
                Text(track.title)
                    .font(.headline)

                Spacer()
                
                // Favorite toggle
                Button(action: {
                    toggleFavorite(for: track)
                }) {
                    Image(systemName: track.favorite ? "heart.fill" : "heart")
                        .foregroundColor(track.favorite ? .indigo : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Play count
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                        .frame(width: 16, alignment: .trailing)
                    Text("\(track.playCount)")
                        .foregroundColor(.secondary)
                        .frame(minWidth: 8, alignment: .leading)
                }
                .frame(width: 80, alignment: .trailing)

                // Duration on the right
                Text(track.durationString)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.vertical, 8) // Add padding within the row
            .padding(.horizontal, 8)
            .background(trackBackground(for: track, in: tracks))
            .cornerRadius(4)
            .contentShape(Rectangle()) // Ensures full row is tappable
            .onTapGesture {
                // Single-click to select the track
                selectedTrack = track
                print("Selecting \(track.title)")
            }
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    // Double-click to play the track
                    print("Double-click, try to play \(track.title)")
                    selectedTrack = track
                    
                    PlaybackManager.shared.play(track: track, tracks: tracks)
                }
            )
            .listRowSeparator(.hidden) // Remove separator between rows
            .listRowInsets(EdgeInsets()) // Remove all default List row insets
            .contextMenu {
                Button("Reset Play Count") {
                    libraryViewModel.resetPlayCountForTrack(for: track, context: modelContext)
                }
                
                Divider()
                
                Menu("Add to Playlist") {
                    let playlists = (try? modelContext.fetch(FetchDescriptor<Playlist>())) ?? []
                    
                    ForEach(playlists) { playlist in
                        Button {
                            playlist.addTrack(track)
                            try? modelContext.save()
                        } label: {
                            Label(playlist.name, systemImage: "music.note.list")
                        }
                    }
                    
                    if playlists.isEmpty {
                        Text("No Playlists")
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Button {
                        showNewPlaylistSheet = true
                        trackToAddToNewPlaylist = track
                    } label: {
                        Label("New Playlist...", systemImage: "plus")
                    }
                }
            }
        }
    }
    
    private func toggleFavorite(for track: Track) {
        track.favorite.toggle()
        do {
            try modelContext.save()
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
    
    private func trackBackground(for track: Track, in tracks: [Track]) -> Color {
        if selectedTrack == track {
            return Color.indigo.opacity(0.4)
        } else if let index = tracks.firstIndex(where: { $0.id == track.id }), index.isMultiple(of: 2) {
            return Color.clear
        } else {
            return Color.black.opacity(0.1)
        }
    }
    
    private func playFirstTrack() {
        playTask?.cancel()
        playTask = Task {
            guard let firstTrack = album.tracks.sorted(by: { $0.trackNumber < $1.trackNumber }).first else {
                print("No tracks available to play.")
                return
            }
            await MainActor.run {
                PlaybackManager.shared.play(track: firstTrack, tracks: PlaybackManager.shared.playQueue)
            }
        }
    }
}
