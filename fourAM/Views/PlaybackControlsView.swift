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
            HStack(alignment: .center) {
                // Album artwork and track details
                HStack(spacing: 8) {
                    if let artworkData = playbackManager.currentTrack?.artwork, let nsImage = NSImage(data: artworkData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50) // Fixed size for album artwork
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
                HStack(spacing: 16) {
                    Button(action: {
                        playbackManager.toggleShuffle()
                    }) {
                        Image(systemName: playbackManager.isShuffleEnabled ? "shuffle.circle.fill" : "shuffle.circle")
                            .font(.title2)
                            .foregroundColor(playbackManager.isShuffleEnabled ? .blue : .primary)
                    }
                    .buttonStyle(PlainButtonStyle()) // Removes any default button background styling

                    Button(action: {
                        playbackManager.previousTrack()
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())

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
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        playbackManager.stop()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        playbackManager.nextTrack()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        playbackManager.toggleRepeat()
                    }) {
                        Image(systemName: playbackManager.isRepeatEnabled ? "repeat.circle.fill" : "repeat.circle")
                            .font(.title2)
                            .foregroundColor(playbackManager.isRepeatEnabled ? .blue : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
            }
           
            .frame(height: 50)
        }
        .background(Color(.windowBackgroundColor)) // Matches system theme
        .shadow(radius: 2) // Subtle shadow to lift the playback bar
    }
}
