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

                // Playback Controls
                HStack {
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

                    Button(action: {
                        playbackManager.stop()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                    }
                }
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor)) // Matches system theme
        .shadow(radius: 2) // Subtle shadow to lift the playback bar
    }
}
