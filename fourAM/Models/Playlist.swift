import Foundation
import SwiftData

@Model
final class Playlist: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .nullify) var tracks: [Track]
    var dateCreated: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.tracks = []
        self.dateCreated = Date()
    }
    
    func addTrack(_ track: Track) {
        if !tracks.contains(where: { $0.id == track.id }) {
            tracks.append(track)
        }
    }
    
    func removeTrack(_ track: Track) {
        tracks.removeAll { $0.id == track.id }
    }
} 