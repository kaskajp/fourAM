//
//  BookmarkManager.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//
// MARK: - BookmarkManager.swift
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

    // Store a bookmark for a given file or folder
    static func storeBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        var dict = bookmarksDict
        dict[url.path] = bookmarkData
        bookmarksDict = dict
    }

    // Resolve a previously stored bookmark
    static func resolveBookmark(for path: String) -> URL? {
        guard let data = bookmarksDict[path] else { return nil }
        var isStale = false
        do {
            let resolvedURL = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
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
    
    static func allStoredFolderPaths() -> [String] {
        return Array(bookmarksDict.keys)
    }
}
