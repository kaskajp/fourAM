//
//  PlaybackControlsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct PlaybackControlsView: View {
    @ObservedObject var playbackManager = PlaybackManager.shared

    var body: some View {
        VStack {
            Divider() // Separates the playback bar from the rest of the app

            HStack {
                if let track = playbackManager.currentTrack {
                    // Display the current track details
                    VStack(alignment: .leading) {
                        Text(track.title)
                            .font(.headline)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Placeholder when no track is selected
                    Text("No Track Playing")
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                // Scrubber
                if let duration = playbackManager.trackDuration, duration > 0 {
                    VStack {
                        Slider(
                            value: $playbackManager.currentTime,
                            in: 0...duration,
                            onEditingChanged: { isEditing in
                                if isEditing {
                                    playbackManager.pause()
                                } else {
                                    playbackManager.seek(to: playbackManager.currentTime)
                                    playbackManager.resume()
                                }
                            }
                        )
                        .accentColor(.blue) // Adjust scrubber color as needed

                        // Time Labels
                        HStack {
                            Text(playbackManager.formattedTime(for: playbackManager.currentTime))
                                .font(.caption)
                            Spacer()
                            Text(playbackManager.formattedTime(for: duration))
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()

                // Playback Controls
                HStack {
                    // Shuffle Button
                    Button(action: {
                        playbackManager.toggleShuffle()
                    }) {
                        Image(systemName: playbackManager.isShuffleEnabled ? "shuffle.circle.fill" : "shuffle.circle")
                            .font(.title2)
                            .foregroundColor(playbackManager.isShuffleEnabled ? .blue : .primary)
                    }

                    // Previous Button
                    Button(action: {
                        playbackManager.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }

                    // Play/Pause Button
                    Button(action: {
                        if playbackManager.isPlaying {
                            playbackManager.pause()
                        } else {
                            playbackManager.resume()
                        }
                    }) {
                        Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }

                    // Stop Button
                    Button(action: {
                        playbackManager.stop()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                    }
                    
                    // Next Button
                    Button(action: {
                        playbackManager.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }

                    // Repeat Button
                    Button(action: {
                        playbackManager.toggleRepeat()
                    }) {
                        Image(systemName: playbackManager.isRepeatEnabled ? "repeat.circle.fill" : "repeat.circle")
                            .font(.title2)
                            .foregroundColor(playbackManager.isRepeatEnabled ? .blue : .primary)
                    }
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor)) // Matches system theme
        .shadow(radius: 2) // Subtle shadow to lift the playback bar
    }
}
