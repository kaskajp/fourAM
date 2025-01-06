//
//  FileScanner.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import Foundation

class FileScanner {
    static func scanLibrary(folderPath: String) -> [URL] {
        let fm = FileManager.default
        var musicFiles = [URL]()
        let supportedExtensions = ["mp3", "aac", "flac", "m4a"] // add or remove as needed

        if let enumerator = fm.enumerator(at: URL(fileURLWithPath: folderPath),
                                          includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                    musicFiles.append(fileURL)
                }
            }
        }
        return musicFiles
    }
}
