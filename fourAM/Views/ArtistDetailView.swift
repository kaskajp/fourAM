import SwiftUI
import AppKit

struct ArtistDetailView: View {
    let artist: String
    let albums: [Album]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Tracks by \(artist)")
                .font(.title)
                .padding(.bottom)

            List {
                ForEach(albums) { album in
                    Section {
                        ForEach(album.tracks) { track in
                            HStack {
                                Text("\(track.trackNumber)")
                                    .frame(width: 30, alignment: .leading)
                                Text(track.title).font(.headline)
                                Spacer()
                                Text(track.durationString)
                            }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            if let data = album.artwork,
                               let nsImage = NSImage(data: data) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(4)
                                    .clipped()
                            } else {
                                // Placeholder
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(4)
                            }
                            Text(album.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding()
        .navigationTitle(artist)
    }
}
