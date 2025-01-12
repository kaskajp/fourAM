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
    private var audioPlayer: AVAudioPlayer?

    @Published var currentTrack: Track? // Currently playing track
    @Published var isPlaying: Bool = false // Playback state
    @Published var isShuffleEnabled = false
    @Published var isRepeatEnabled = false
    @Published var currentTime: Double = 0 // Current playback time in seconds
    
    var library: [Track] = [] // Array of tracks representing the music library
    private var currentIndex: Int? // Index of the currently playing track
    
    var trackDuration: Double? {
        audioPlayer?.duration
    }

    private var timer: Timer?

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
                startTimer()
                currentTrack = track
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
    
    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let player = self.audioPlayer {
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func formattedTime(for time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func nextTrack() {
        guard let index = currentIndex else { return }
        if isShuffleEnabled {
            currentIndex = Int.random(in: 0..<library.count)
        } else {
            currentIndex = (index + 1) % library.count
        }
        if let currentIndex = currentIndex {
            play(track: library[currentIndex])
        }
    }

    func previousTrack() {
        guard let index = currentIndex else { return }
        currentIndex = (index - 1 + library.count) % library.count
        if let currentIndex = currentIndex {
            play(track: library[currentIndex])
        }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }
    
    func setLibrary(_ tracks: [Track]) {
        library = tracks
    }

    func startPlayingLibrary(from index: Int) {
        guard index < library.count else { return }
        currentIndex = index
        play(track: library[index])
    }
}
