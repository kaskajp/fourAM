//
//  AlbumArtView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import SwiftUI

struct AlbumArtView: View {
    let artwork: Data?

    var body: some View {
        if let data = artwork, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color.gray)
                .aspectRatio(1, contentMode: .fit)
        }
    }
}
