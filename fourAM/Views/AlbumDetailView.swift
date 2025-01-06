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

    var body: some View {
        VStack(alignment: .leading) {
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

            // Track list
            List(album.tracks) { track in
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
            }
        }
        .padding()
        .navigationTitle(album.name) // or just .navigationTitle("Album Details")
    }
}
