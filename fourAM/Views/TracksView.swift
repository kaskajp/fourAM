import SwiftUI

struct TracksView: View {
    @ObservedObject var libraryViewModel: LibraryViewModel

    var body: some View {
        List(libraryViewModel.tracks) { track in
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.headline)
                Text("\(track.artist) – \(track.album)")
                    .font(.subheadline)
            }
        }
        .navigationTitle("Tracks")
    }
}
