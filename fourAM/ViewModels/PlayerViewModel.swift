//
//  PlayerViewModel.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import Foundation

class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    private let audioPlayer = AudioPlayer()

    func play(file: Track) {
        currentTrack = file
        audioPlayer.play(file: file)
    }

    func pause() {
        audioPlayer.pause()
    }

    func stop() {
        audioPlayer.stop()
    }
}
