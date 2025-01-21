import SwiftData
import Foundation

struct AlbumKey: Hashable {
    let album: String
    let disc: Int
}

class LibraryHelper {
    static func fetchTracks(from context: ModelContext) -> [Track] {
        do {
            let fetchDescriptor = FetchDescriptor<Track>()
            let tracks = try context.fetch(fetchDescriptor)
            
            // Group by album and discNumber using AlbumKey
            let groupedTracks = Dictionary(grouping: tracks, by: { track in
                AlbumKey(album: track.album, disc: track.discNumber)
            })

            // Sort albums alphabetically, then sort tracks by disc and track number
            let sortedTracks = groupedTracks
                .sorted { lhs, rhs in
                    // Sort by album name first, then disc number
                    if lhs.key.album != rhs.key.album {
                        return lhs.key.album < rhs.key.album
                    }
                    return lhs.key.disc < rhs.key.disc
                }
                .flatMap { discGroup in
                    // Sort tracks within each group by trackNumber
                    discGroup.value.sorted { $0.trackNumber < $1.trackNumber }
                }

            return sortedTracks
        } catch {
            print("Failed to fetch tracks: \(error)")
            return []
        }
    }
    
    static func findTopLevelFolder(for filePath: String) -> String? {
        let allTopLevelFolders = BookmarkManager.allStoredFolderPaths()
        return allTopLevelFolders.first { filePath.hasPrefix($0) }
    }
}
