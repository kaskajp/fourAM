//
//  AudioFile.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import Foundation

struct AudioFile: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String
    let album: String
    let artwork: Data?
    let trackNumber: Int
    let durationString: String
}
