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
        // Normalize the path to handle double slashes
        let normalizedPath = url.path.replacingOccurrences(of: "//", with: "/")
        let normalizedURL = URL(fileURLWithPath: normalizedPath)
        
        // Using more comprehensive security options for bookmarks
        let bookmarkData = try normalizedURL.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: [.nameKey, .isDirectoryKey],
            relativeTo: nil
        )
        
        var dict = bookmarksDict
        dict[normalizedPath] = bookmarkData
        bookmarksDict = dict
        
        print("Bookmark stored for: \(normalizedPath) with enhanced security options")
    }
    
    // Explicitly request and store access for folder and subfolders
    static func storeSecureAccessForFolder(at url: URL) throws -> Bool {
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to start accessing security scope for \(url.path)")
            return false
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Store bookmark for the parent folder with full access (read/write)
        try storeBookmarkWithFullAccess(for: url)
        
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
    
    // Store a bookmark with full access rights (needed for folders)
    static func storeBookmarkWithFullAccess(for url: URL) throws {
        // Normalize the path to handle double slashes
        let normalizedPath = url.path.replacingOccurrences(of: "//", with: "/")
        let normalizedURL = URL(fileURLWithPath: normalizedPath)
        
        // Using security scope but without read-only limitation
        let bookmarkData = try normalizedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.nameKey, .isDirectoryKey],
            relativeTo: nil
        )
        
        var dict = bookmarksDict
        dict[normalizedPath] = bookmarkData
        bookmarksDict = dict
        
        print("Bookmark stored with FULL access for: \(normalizedPath)")
    }

    // Resolve a previously stored bookmark with error handling
    static func resolveBookmark(for path: String) -> URL? {
        // Normalize the path to handle double slashes
        let normalizedPath = path.replacingOccurrences(of: "//", with: "/")
        
        // First check if we have a direct bookmark for this path
        if let data = bookmarksDict[normalizedPath] {
            return resolveBookmarkData(data, forPath: normalizedPath)
        } else if let data = bookmarksDict[path] {
            // Also try with the original path
            return resolveBookmarkData(data, forPath: path)
        }
        
        // If no direct bookmark, check if this file is within a folder we have bookmark access to
        let allFolders = bookmarksDict.keys
        
        // Find matching parent folders, normalizing paths to handle double slashes
        let parentFolders = allFolders.filter { folderPath in
            let normalizedFolder = folderPath.replacingOccurrences(of: "//", with: "/")
            return (normalizedPath.hasPrefix(normalizedFolder) && normalizedPath != normalizedFolder) ||
                   (normalizedPath.hasPrefix(folderPath) && normalizedPath != folderPath)
        }.sorted(by: { $0.count > $1.count }) // Sort by length to get the most specific parent
        
        if let parentFolder = parentFolders.first, let data = bookmarksDict[parentFolder] {
            var isStale = false
            do {
                let resolvedFolderURL = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                if isStale {
                    print("Parent bookmark is stale for \(parentFolder), removing...")
                    removeBookmark(for: parentFolder)
                    return nil
                }
                
                // Construct the file URL relative to the parent folder
                var relativePath = ""
                
                if normalizedPath.hasPrefix(parentFolder) {
                    relativePath = String(normalizedPath.dropFirst(parentFolder.count))
                } else {
                    let normalizedFolder = parentFolder.replacingOccurrences(of: "//", with: "/")
                    relativePath = String(normalizedPath.dropFirst(normalizedFolder.count))
                }
                
                // Ensure the relative path doesn't start with a slash
                if relativePath.hasPrefix("/") {
                    relativePath = String(relativePath.dropFirst())
                }
                
                // Create a file URL for the target file
                let fileURL = resolvedFolderURL.appendingPathComponent(relativePath)
                
                // Try to create a security-scoped bookmark for this specific file too
                // This will help future access to work better
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        try storeBookmark(for: fileURL)
                        print("Created new security-scoped bookmark for child file: \(fileURL.path)")
                    } catch {
                        print("Note: Could not create security bookmark for child: \(error)")
                        // Continue anyway - we'll use the parent folder's security scope
                    }
                }
                
                print("Resolved from parent folder: \(parentFolder) -> \(fileURL.path)")
                return fileURL
            } catch {
                print("Error resolving parent bookmark for \(parentFolder): \(error)")
                return nil
            }
        }
        
        print("No bookmark data found for \(path)")
        return nil
    }
    
    // Helper method to resolve bookmark data
    private static func resolveBookmarkData(_ data: Data, forPath path: String) -> URL? {
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
