//
//  AlbumDetailView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI
import AppKit

struct AlbumDetailView: View {
    let album: Album
        
    @State private var selectedTrack: Track? // Track currently selected

    var body: some View {
        let groupedTracks = Dictionary(grouping: album.tracks) { $0.discNumber ?? 1 }
        let sortedDiscs = groupedTracks.keys.sorted()

        // Debug grouping logic outside of the ViewBuilder
        // debugGroupedTracks(groupedTracks)

        return VStack(alignment: .leading) {
            // Album header (cover + album title)
            HStack(spacing: 8) {
                if let data = album.artwork,
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(4)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 60, height: 60)
                        .cornerRadius(4)
                }
                Text(album.name)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 8)

            // Track list grouped by disc
            List {
                ForEach(sortedDiscs, id: \.self) { disc in
                    Section(header: Text("Disc \(disc)").font(.headline)) {
                        ForEach(groupedTracks[disc]!.sorted(by: { lhs, rhs in
                            lhs.trackNumber < rhs.trackNumber
                        }), id: \.id) { track in
                            HStack {
                                // Track number on the left
                                Text("\(track.trackNumber)")
                                    .frame(width: 30, alignment: .leading)

                                // Track title in the center
                                Text(track.title)
                                    .font(.headline)

                                Spacer()

                                // Duration on the right
                                Text(track.durationString)
                            }
                            .padding(4)
                            .background(selectedTrack == track ? Color.blue.opacity(0.2) : Color.clear) // Highlight selected track
                            .cornerRadius(4)
                            .contentShape(Rectangle()) // Ensures full row is tappable
                            .onTapGesture {
                                // Single-click to select the track
                                selectedTrack = track
                                print("Selecting \(track.title)")
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    // Double-click to play the track
                                    print("Double-click, try to play \(track.title)")
                                    selectedTrack = track
                                    PlaybackManager.shared.play(track: track)
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle(album.name) // or just .navigationTitle("Album Details")
    }

    private func debugGroupedTracks(_ groupedTracks: [Int: [Track]]) {
        print("Grouped Tracks:")
        for (disc, tracks) in groupedTracks {
            print("Disc \(disc):")
            for track in tracks {
                print("  - \(track.trackNumber): \(track.title)")
            }
        }
    }
}
