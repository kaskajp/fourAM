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
            let supportedExtensions = Set(["mp3", "aac", "flac", "m4a"])
            
            // Create a concurrent queue for processing files
            let processingQueue = DispatchQueue(label: "com.fourAM.fileProcessing", attributes: .concurrent)
            let group = DispatchGroup()
            
            // Use a concurrent array to store results
            let results = NSMutableArray()
            let resultsLock = NSLock()
            
            // Configure the enumerator with better performance options
            let enumeratorOptions: FileManager.DirectoryEnumerationOptions = [
                .skipsHiddenFiles,
                .skipsPackageDescendants
            ]
            
            // First, get all files recursively
            var allFiles: [URL] = []
            if let enumerator = fm.enumerator(
                at: URL(fileURLWithPath: folderPath),
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: enumeratorOptions
            ) {
                while let itemURL = enumerator.nextObject() as? URL {
                    var isDirectory: ObjCBool = false
                    if fm.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                        if !isDirectory.boolValue && supportedExtensions.contains(itemURL.pathExtension.lowercased()) {
                            allFiles.append(itemURL)
                        }
                    }
                }
            }
            
            let totalFiles = allFiles.count
            print("Found \(totalFiles) total music files to process")
            
            // Process files in batches for better performance
            let batchSize = 50
            for i in stride(from: 0, to: allFiles.count, by: batchSize) {
                let end = min(i + batchSize, allFiles.count)
                let batch = Array(allFiles[i..<end])
                
                group.enter()
                processingQueue.async {
                    defer { group.leave() }
                    
                    for fileURL in batch {
                        resultsLock.lock()
                        results.add(fileURL)
                        resultsLock.unlock()
                        
                        let processedCount = results.count
                        if processedCount % 50 == 0 {
                            let progress = Double(processedCount) / Double(totalFiles)
                            DispatchQueue.main.async {
                                progressHandler(progress)
                            }
                        }
                    }
                }
            }
            
            // Wait for all processing to complete
            group.wait()
            
            // Convert results to array and sort by modification date
            let musicFiles = (results as NSArray as? [URL]) ?? []
            let sortedFiles = musicFiles.sorted { file1, file2 in
                guard let date1 = try? file1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      let date2 = try? file2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                    return false
                }
                return date1 > date2
            }
            
            print("Successfully processed \(sortedFiles.count) music files")
            
            // Completion handler on the main thread
            DispatchQueue.main.async {
                completion(sortedFiles)
            }
        }
    }
}
