import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var playbackManager = PlaybackManager.shared
    
    @State private var scrubberTime: Double = 0 // Local state for scrubber value

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                // Album artwork and track details
                HStack(spacing: 8) {
                    if let track = playbackManager.currentTrack {
                        OptimizedAlbumArtView(
                            thumbnailData: track.thumbnail,
                            albumId: track.id.uuidString,
                            size: 50
                        )
                        .shadow(radius: 2) // Subtle shadow
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3)) // Placeholder for missing artwork
                            .frame(width: 50, height: 50)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let track = playbackManager.currentTrack {
                            Text(track.title)
                                .font(.headline)
                                .lineLimit(1) // Avoid text overflowing
                            Text(track.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No Track Playing")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 200, alignment: .leading) // Fixed width for consistent layout
                }

                Spacer()
                
                // Scrubber
                if let duration = playbackManager.trackDuration, duration > 0 {
                    VStack(alignment: .center) {
                        Slider(
                            value: $scrubberTime,
                            in: 0...duration,
                            onEditingChanged: { isEditing in
                                if isEditing {
                                    playbackManager.pause()
                                } else {
                                    playbackManager.seek(to: scrubberTime)
                                    playbackManager.resume()
                                }
                            }
                        )
                        .accentColor(.blue) // Adjust scrubber color as needed

                        // Time Labels
                        HStack {
                            Text(playbackManager.formattedTime(for: scrubberTime))
                                .font(.caption)
                            Spacer()
                            Text(playbackManager.formattedTime(for: duration))
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .onAppear {
                        scrubberTime = playbackManager.currentTime
                    }
                    .onChange(of: playbackManager.currentTime) { oldValue, newValue in
                        scrubberTime = newValue
                    }
                }
                
                Spacer()
                
                // Playback Controls
                playbackControls
            }
           
            .frame(height: 50)
        }
        .background(Color(.windowBackgroundColor)) // Matches system theme
        .shadow(radius: 2) // Subtle shadow to lift the playback bar
    }
    
    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button(action: playbackManager.toggleShuffle) {
                Image(systemName: playbackManager.isShuffleEnabled ? "shuffle.circle.fill" : "shuffle.circle")
                    .font(.title2)
                    .foregroundColor(playbackManager.isShuffleEnabled ? .indigo : .primary)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: playbackManager.previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                playbackManager.isPlaying ? playbackManager.pause() : playbackManager.resume()
            }) {
                Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: playbackManager.stop) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: playbackManager.nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: playbackManager.toggleRepeat) {
                Image(systemName: playbackManager.isRepeatEnabled ? "repeat.circle.fill" : "repeat.circle")
                    .font(.title2)
                    .foregroundColor(playbackManager.isRepeatEnabled ? .indigo : .primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
}
