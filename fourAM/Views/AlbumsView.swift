//
//  AlbumsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI
import AppKit

struct AlbumsView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel

    // A simple adaptive grid
    let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(libraryViewModel.allAlbums()) { album in
                    // Wrap your album UI in a NavigationLink
                    NavigationLink(destination: AlbumDetailView(album: album)) {
                        VStack {
                            // Show cover art or a placeholder
                            if let data = album.artwork,
                               let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(4)
                                    .clipped()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0))
                                    .frame(width: 120, height: 120)
                                    .cornerRadius(4)
                            }
                            
                            // Album name
                            Text(album.name)
                                .font(.headline)
                                .frame(maxWidth: 120)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Albums")
    }
}
