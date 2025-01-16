//
//  ThumbnailCache.swift
//  fourAM
//
//  Created by Jonas on 2025-01-16.
//

import SwiftUI

actor ThumbnailCache {
    private var cache: [String: Data] = [:]
    private var pending: [String: CheckedContinuation<Data?, Never>] = [:]

    func getThumbnail(for album: String) -> Data? {
        return cache[album]
    }

    func setThumbnail(_ data: Data, for album: String) {
        cache[album] = data
        
        // Resolve any pending continuation for this album
        if let continuation = pending.removeValue(forKey: album) {
            continuation.resume(returning: data)
        }
    }

    func waitForThumbnail(for album: String) async -> Data? {
        if let cachedThumbnail = cache[album] {
            return cachedThumbnail // Return immediately if cached
        }
        
        return await withCheckedContinuation { continuation in
            pending[album] = continuation
        }
    }
    
    func clear() {
        cache.removeAll()
    }
}
