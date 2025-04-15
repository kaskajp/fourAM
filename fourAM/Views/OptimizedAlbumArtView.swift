import SwiftUI
import AppKit

struct OptimizedAlbumArtView: View {
    let thumbnailData: Data?
    let albumId: String // Used as a cache key
    let size: CGFloat
    
    // Use a simple image loader instead of a state variable for simplicity
    private var nsImage: NSImage? {
        // Check if image is already in cache
        if let cachedImage = ImageCache.shared.image(for: albumId) {
            return cachedImage
        }
        
        // Not in cache, load from data if available
        guard let data = thumbnailData,
              let newImage = NSImage(data: data) else {
            return nil
        }
        
        // Store in cache
        ImageCache.shared.insert(newImage, for: albumId)
        return newImage
    }
    
    var body: some View {
        Group {
            if let image = nsImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .cornerRadius(4)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: size, height: size)
                    .cornerRadius(4)
            }
        }
    }
} 