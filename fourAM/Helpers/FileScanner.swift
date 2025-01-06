//
//  FileScanner.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import Foundation

class FileScanner {
    /// Asynchronously scans the folder for music files, calls `progressHandler` periodically,
    /// then calls `completion` with the result.
    static func scanLibraryAsync(
        folderPath: String,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping ([URL]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let supportedExtensions = ["mp3", "aac", "flac", "m4a"]

            // Collect all items once so we know total count (for progress).
            // Note: enumerator.allObjects can be expensive for huge directories,
            // but it lets us show a proper progress bar.
            guard let enumerator = fm.enumerator(at: URL(fileURLWithPath: folderPath),
                                                 includingPropertiesForKeys: nil),
                  let allItems = enumerator.allObjects as? [URL] else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            let totalCount = allItems.count
            var scannedCount = 0
            var musicFiles = [URL]()

            // Scan each item
            for fileURL in allItems {
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    musicFiles.append(fileURL)
                }
                scannedCount += 1

                // Update progress every so often (e.g., every 50 files)
                if scannedCount % 50 == 0 || scannedCount == totalCount {
                    let progress = Double(scannedCount) / Double(totalCount)
                    DispatchQueue.main.async {
                        progressHandler(progress)
                    }
                }
            }

            // Completion handler on the main thread
            DispatchQueue.main.async {
                completion(musicFiles)
            }
        }
    }
}
