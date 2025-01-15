//
//  ArtistsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct ArtistsView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel

    var body: some View {
        NavigationStack {
            List(libraryViewModel.allArtists, id: \.self) { artist in
                NavigationLink(
                    destination: ArtistDetailView(
                        artist: artist,
                        albums: libraryViewModel.albums(for: artist)
                    )
                ) {
                    Text(artist)
                }
            }
            .navigationTitle("Artists")
        }
    }
}
