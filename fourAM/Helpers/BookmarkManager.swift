//
//  BookmarkManager.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//
// MARK: - BookmarkManager.swift
import SwiftUI

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

    static func storeBookmark(for folderURL: URL) throws {
        let data = try folderURL.bookmarkData(options: .withSecurityScope,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil)
        var dict = bookmarksDict
        dict[folderURL.path] = data
        bookmarksDict = dict
    }

    static func resolveBookmark(for folderPath: String) -> URL? {
        guard let data = bookmarksDict[folderPath] else { return nil }
        var isStale = false
        do {
            let resolvedURL = try URL(resolvingBookmarkData: data,
                                      options: .withSecurityScope,
                                      relativeTo: nil,
                                      bookmarkDataIsStale: &isStale)
            if isStale {
                removeBookmark(for: folderPath)
                return nil
            }
            return resolvedURL
        } catch {
            print("Error resolving bookmark: \(error)")
            return nil
        }
    }

    static func removeBookmark(for folderPath: String) {
        var dict = bookmarksDict
        dict.removeValue(forKey: folderPath)
        bookmarksDict = dict
    }
    
    static func allStoredFolderPaths() -> [String] {
        return Array(bookmarksDict.keys)
    }
}
