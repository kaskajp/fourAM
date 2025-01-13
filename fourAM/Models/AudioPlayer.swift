//
//  AudioPlayer.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import AVFoundation

class AudioPlayer: ObservableObject {
    private var player: AVAudioPlayer?

    @Published var isPlaying = false

    func play(file: Track) {
        do {
            player = try AVAudioPlayer(contentsOf: file.url)
            player?.play()
            isPlaying = true
        } catch {
            print("Error playing file: \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }
}
