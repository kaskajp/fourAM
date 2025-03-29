import Foundation
import SwiftData

actor LibraryModelActor {
    private let context: ModelContext
    
    init(modelDescriptor: ModelConfiguration) {
        let container = try! ModelContainer(for: Track.self, configurations: modelDescriptor)
        self.context = ModelContext(container)
    }
    
    func deleteAllTracks() async throws {
        let descriptor = FetchDescriptor<Track>()
        let tracks = try context.fetch(descriptor)
        
        for track in tracks {
            context.delete(track)
        }
        
        try context.save()
    }
    
    func fetchAllTracks() async throws -> [Track] {
        let descriptor = FetchDescriptor<Track>()
        return try context.fetch(descriptor)
    }
}
