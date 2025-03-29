import SwiftData
import Foundation

@Model
class Track: Equatable {
    var id: UUID = UUID()
    @Attribute(.unique) var path: String
    var url: URL
    var title: String
    var artist: String
    var album: String
    var discNumber: Int
    var albumArtist: String?
    var artwork: Data?
    var thumbnail: Data?
    var trackNumber: Int
    var durationString: String
    var genre: String?
    var releaseYear: Int
    var playCount: Int = 0
    var favorite: Bool = false
    @Relationship(deleteRule: .nullify) var playlists: [Playlist]

    init(
        path: String,
        url: URL,
        title: String,
        artist: String,
        album: String,
        discNumber: Int = -1,
        albumArtist: String? = nil,
        artwork: Data? = nil,
        thumbnail: Data? = nil,
        trackNumber: Int = -1,
        durationString: String = "0:00",
        genre: String? = nil,
        releaseYear: Int = 0,
        playCount: Int = 0,
        favorite: Bool = false
    ) {
        self.path = path
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.discNumber = discNumber
        self.albumArtist = albumArtist
        self.artwork = artwork
        self.thumbnail = thumbnail
        self.trackNumber = trackNumber
        self.durationString = durationString
        self.genre = genre
        self.releaseYear = releaseYear
        self.playCount = playCount
        self.favorite = favorite
        self.playlists = []
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id // Ensure you're comparing unique identifiers
    }
}
