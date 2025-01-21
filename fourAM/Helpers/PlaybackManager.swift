//
//  PlaybackManager.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class PlaybackManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = PlaybackManager()
    private var audioPlayer: AVAudioPlayer?
    
    @ObservedObject var libraryViewModel = LibraryViewModel.shared

    @Published var currentTrack: Track? // Currently playing track
    @Published var isPlaying: Bool = false // Playback state
    @Published var isShuffleEnabled = false
    @Published var isRepeatEnabled = false
    @Published private(set) var currentTime: Double = 0 {
        didSet {
            throttledCurrentTime.send(currentTime)
        }
    }
    private let throttledCurrentTime = PassthroughSubject<Double, Never>()
    var throttledTimePublisher: AnyPublisher<Double, Never> {
        throttledCurrentTime
            .throttle(for: .milliseconds(500), scheduler: RunLoop.main, latest: true)
            .eraseToAnyPublisher()
    }
    @Published var playQueue: [Track] = [] // Tracks in the "Up Next" queue
    @Published var playHistory: [Track] = [] // List of played tracks in order
    @Published var currentIndex: Int? // Index of the currently playing track
    
    var trackDuration: Double? {
        audioPlayer?.duration
    }

    private var timer: Timer?

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
                audioPlayer?.delegate = self
                audioPlayer?.play()
                
                // Update the current index
                if let index = libraryViewModel.tracks.firstIndex(where: { $0.path == track.path }) {
                    currentIndex = index
                } else {
                    currentIndex = nil
                }
                
                currentTrack = track
                isPlaying = true
                
                // Add the current track to the history if it's not already the last played
                if let currentTrack = currentTrack, playHistory.last != currentTrack {
                    playHistory.append(currentTrack)
                }

                startTimer()
                updateQueue()
                print("Playing \(track.title)")
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
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("Track finished playing. Moving to the next track.")
            nextTrack()
        } else {
            print("Playback finished unsuccessfully.")
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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
    
    func updateQueue() {
        guard let currentIndex = currentIndex, libraryViewModel.tracks.indices.contains(currentIndex) else {
            playQueue = []
            print("Queue update failed: invalid currentIndex or empty tracks array")
            return
        }

        let nextTracks = libraryViewModel.tracks[(currentIndex + 1)...].prefix(10)
        playQueue = Array(nextTracks)
        print("Queue updated, count: \(playQueue.count)")
    }

    func nextTrack() {
        guard let currentIndex = currentIndex else {
            print("Error: currentIndex is nil")
            return
        }
        
        if isShuffleEnabled {
            self.currentIndex = Int.random(in: 0..<libraryViewModel.tracks.count)
        } else {
            self.currentIndex = (currentIndex + 1) % libraryViewModel.tracks.count
        }
        
        if let nextIndex = self.currentIndex {
            play(track: libraryViewModel.tracks[nextIndex])
        } else {
            print("Error: nextIndex is nil")
        }
    }

    func previousTrack() {
        // Ensure there is at least one previous track in history
        guard playHistory.count > 1 else {
            print("No previous track available in history.")
            return
        }

        // Remove the current track from the playHistory if it matches
        if let currentTrack = currentTrack, playHistory.last == currentTrack {
            playHistory.removeLast()
        }

        // Ensure playHistory still has tracks
        guard let lastPlayedTrack = playHistory.last else {
            print("No more tracks in history.")
            return
        }

        // Find the index of the last played track in the library and play it
        if let previousIndex = libraryViewModel.tracks.firstIndex(of: lastPlayedTrack) {
            currentIndex = previousIndex
            play(track: libraryViewModel.tracks[previousIndex])
            print("Playing previous track: \(lastPlayedTrack.title)")
        } else {
            print("Previous track not found in library: \(lastPlayedTrack.path)")
        }
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }
}
