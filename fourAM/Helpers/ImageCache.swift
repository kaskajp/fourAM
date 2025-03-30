import Foundation
import AppKit

// A simple in-memory cache for NSImage objects
final class ImageCache {
    static let shared = ImageCache()
    
    // LRU cache with capacity limit
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        // Configure cache with default settings
        cache.countLimit = 100
    }
    
    // Configure cache with custom settings
    func configure(countLimit: Int = 100) {
        cache.countLimit = countLimit
    }
    
    func image(for key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func insert(_ image: NSImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func remove(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
} 