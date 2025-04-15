import SwiftUI
import SwiftData

struct TrackRowView: View {
    let track: Track
    @Binding var isPlaying: Bool
    let trackIndex: Int
    let showAlbumInfo: Bool
    let modelContext: ModelContext
    
    var body: some View {
        HStack(spacing: 10) {
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
                    .lineLimit(1)
                
                if showAlbumInfo {
                    Text("\(track.artist) • \(track.album)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Play indicator
            if isPlaying {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.indigo)
                    .padding(.trailing, 5)
            }
            
            // Play count
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("\(track.playCount)")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .frame(width: 50)
            
            // Duration
            Text(track.durationString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(rowBackground)
    }
    
    private var rowBackground: some View {
        Group {
            if isPlaying {
                Color.indigo.opacity(0.1)
            } else if trackIndex.isMultiple(of: 2) {
                Color.clear
            } else {
                Color.black.opacity(0.05)
            }
        }
    }
}