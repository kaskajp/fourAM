//
//  LibraryHelper.swift
//  fourAM
//
//  Created by Jonas on 2025-01-07.
//

import SwiftData

class LibraryHelper {
    static func fetchTracks(from context: ModelContext) -> [Track] {
        do {
            let fetchDescriptor = FetchDescriptor<Track>()
            let tracks = try context.fetch(fetchDescriptor)
            print("Fetched \(tracks.count) tracks.")
            return tracks
        } catch {
            print("Failed to fetch tracks: \(error)")
            return []
        }
    }
}
