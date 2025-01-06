//
//  PlaybackManager.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import Foundation
import AVFoundation

class PlaybackManager: ObservableObject {
    static let shared = PlaybackManager()

    @Published var currentTrack: Track? // Currently playing track
    @Published var isPlaying: Bool = false // Playback state

    private var audioPlayer: AVAudioPlayer?

    private init() {}

    // MARK: - Playback Controls

    func play(track: Track) {
        guard let trackURL = URL(string: track.path) else {
            print("Invalid track URL")
            return
        }

        // Resolve the bookmark for the file
        if let resolvedURL = BookmarkManager.resolveBookmark(for: trackURL.path) {
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                print("Failed to start security scope for \(resolvedURL.path)")
                return
            }
            defer { resolvedURL.stopAccessingSecurityScopedResource() }

            // Attempt to play the file
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: resolvedURL)
                audioPlayer?.play()
                currentTrack = track
                isPlaying = true
            } catch {
                print("Failed to play track: \(error)")
            }
        } else {
            print("No valid security bookmark for \(track.path)")
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentTrack = nil
        isPlaying = false
    }
}
