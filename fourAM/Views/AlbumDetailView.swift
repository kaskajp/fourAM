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
    let onBack: () -> Void // Closure to handle the back button action

    @Environment(\.dismiss) var dismiss // Replace presentationMode with dismiss
    @State private var searchText: String = "" // To manage the search input
    @State private var selectedTrack: Track? // Track currently selected

    var body: some View {
        // Group and sort tracks
        let groupedTracks = Dictionary(grouping: album.tracks) { $0.discNumber ?? 1 }
        let sortedDiscs = groupedTracks.keys.sorted()
        let filteredTracks = album.tracks.filter { track in
            searchText.isEmpty || track.title.lowercased().contains(searchText.lowercased())
        }
        let filteredGroupedTracks = Dictionary(grouping: filteredTracks) { $0.discNumber ?? 1 }
        let filteredSortedDiscs = filteredGroupedTracks.keys.sorted()

        return VStack(alignment: .leading) {
            // Top bar
            HStack(alignment: .center) {
                Button(action: onBack) { // Call the provided back action
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                TextField("Filter", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
            }
            .padding(.bottom, 10)
            .zIndex(1)

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
                ForEach(filteredSortedDiscs, id: \.self) { disc in
                    Group {
                        if filteredGroupedTracks.keys.count > 1 {
                            Section(header: Text("Disc \(disc)").font(.headline)) {
                                trackList(for: disc, tracks: filteredGroupedTracks[disc]!)
                            }
                        } else {
                            trackList(for: disc, tracks: filteredGroupedTracks[disc]!)
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle(album.name) // Optional: Keep or remove this
    }
    
    @ViewBuilder
    private func trackList(for disc: Int, tracks: [Track]) -> some View {
        ForEach(tracks.sorted(by: { lhs, rhs in
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
