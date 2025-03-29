import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var playlist: Playlist
    @State private var selectedTrack: Track? = nil
    @State private var playTask: Task<Void, Never>?
    
    var body: some View {
        List(playlist.tracks, selection: $selectedTrack) { track in
            HStack {
                if let thumbnail = track.thumbnail, let nsImage = NSImage(data: thumbnail) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(4)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(track.durationString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contextMenu {
                Button(role: .destructive) {
                    playlist.removeTrack(track)
                    try? modelContext.save()
                } label: {
                    Label("Remove from Playlist", systemImage: "minus.circle")
                }
                
                Divider()
                
                Button {
                    track.playCount = 0
                    try? modelContext.save()
                } label: {
                    Label("Reset Play Count", systemImage: "arrow.counterclockwise")
                }
            }
            .onTapGesture(count: 2) {
                playTask?.cancel()
                playTask = Task {
                    PlaybackManager.shared.play(track: track, tracks: playlist.tracks)
                }
            }
        }
        .navigationTitle(playlist.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        playlist.tracks.removeAll()
                        try? modelContext.save()
                    } label: {
                        Label("Clear Playlist", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
} 