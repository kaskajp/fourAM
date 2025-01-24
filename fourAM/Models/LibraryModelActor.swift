import SwiftData

actor LibraryModelActor {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func deleteAllTracks() throws {
        let fetchDescriptor = FetchDescriptor<Track>()
        let allTracks = try context.fetch(fetchDescriptor)
        for track in allTracks {
            context.delete(track)
        }
        try context.save()
    }

    func fetchAllTracks() throws -> [Track] {
        let fetchDescriptor = FetchDescriptor<Track>()
        return try context.fetch(fetchDescriptor)
    }
}
