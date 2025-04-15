import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()
    var aboutWindow: NSWindow?
    
    // Global search properties
    @Published var globalSearchQuery: String = ""
    @Published var isSearching: Bool = false
    @Published var searchResults: SearchResults = SearchResults()
    
    // Function to clear search
    func clearSearch() {
        globalSearchQuery = ""
        isSearching = false
        searchResults = SearchResults()
    }
}

// Model to hold search results
struct SearchResults {
    var albums: [Album] = []
    var tracks: [Track] = []
    
    var isEmpty: Bool {
        return albums.isEmpty && tracks.isEmpty
    }
    
    var totalCount: Int {
        return albums.count + tracks.count
    }
}
