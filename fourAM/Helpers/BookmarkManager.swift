import Foundation

struct BookmarkManager {
    private static let storedBookmarksKey = "StoredBookmarks"

    private static var bookmarksDict: [String: Data] {
        get {
            UserDefaults.standard.dictionary(forKey: storedBookmarksKey) as? [String: Data] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storedBookmarksKey)
        }
    }

    // Store a bookmark for a given file or folder with enhanced security options
    static func storeBookmark(for url: URL) throws {
        // Using more comprehensive security options for bookmarks
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: [.nameKey, .isDirectoryKey],
            relativeTo: nil
        )
        
        var dict = bookmarksDict
        dict[url.path] = bookmarkData
        bookmarksDict = dict
        
        print("Bookmark stored for: \(url.path) with enhanced security options")
    }
    
    // Explicitly request and store access for folder and subfolders
    static func storeSecureAccessForFolder(at url: URL) throws -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to start accessing security scope for \(url.path)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Store bookmark for the parent folder
        try storeBookmark(for: url)
        
        // Get contents of directory
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        // Process subdirectories recursively
        for itemURL in contents {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                // For directories, process recursively
                try storeSecureAccessForFolder(at: itemURL)
            } else if ["mp3", "m4a", "flac"].contains(itemURL.pathExtension.lowercased()) {
                // For audio files, store individual bookmarks
                try storeBookmark(for: itemURL)
            }
        }
        
        return true
    }

    // Resolve a previously stored bookmark with error handling
    static func resolveBookmark(for path: String) -> URL? {
        guard let data = bookmarksDict[path] else {
            print("No bookmark data found for \(path)")
            return nil
        }
        
        var isStale = false
        do {
            let resolvedURL = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("Bookmark is stale for \(path), removing...")
                removeBookmark(for: path)
                return nil
            }
            
            return resolvedURL
        } catch {
            print("Error resolving bookmark for \(path): \(error)")
            return nil
        }
    }

    // Remove a bookmark for a given path
    static func removeBookmark(for path: String) {
        var dict = bookmarksDict
        dict.removeValue(forKey: path)
        bookmarksDict = dict
    }
    
    // Get all stored folder paths
    static func allStoredFolderPaths() -> [String] {
        return Array(bookmarksDict.keys)
    }
    
    // Debug function to print all stored bookmarks
    static func printAllBookmarks() {
        print("=== Stored Bookmarks ===")
        for (path, _) in bookmarksDict {
            print("- \(path)")
        }
        print("========================")
    }
}
