import SwiftUI
import SwiftData
import AppKit

struct ArtworkSettingsView: View {
    @AppStorage("coverImageSize") private var coverImageSize: Double = 100.0 // Default size
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    @State private var showThumbnailCacheAlert = false
    @State private var isClearingThumbnails = false
    @State private var showRegenerateAlert = false
    @State private var isRegenerating = false
    @State private var cacheSize: Int64 = 0
    @State private var cachePath: String = ""

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Album Cover Size Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Slider(value: $coverImageSize, in: 50...200, step: 10) {
                                Text("Cover Image Size")
                            }
                            Text("Size: \(Int(coverImageSize)) px")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text("Album Cover Size")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Thumbnail Management Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cache size: \(formatFileSize(cacheSize))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                HStack {
                                    Text("Location: \(cachePath)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Button {
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cachePath)
                                    } label: {
                                        Image(systemName: "folder")
                                            .foregroundColor(.indigo)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Show in Finder")
                                }
                            }
                            
                            HStack(spacing: 16) {
                                Button(role: .destructive) {
                                    showThumbnailCacheAlert = true
                                } label: {
                                    Text("Clear Thumbnail Cache")
                                }
                                .help("Remove all cached album art thumbnails")
                                
                                Button {
                                    showRegenerateAlert = true
                                } label: {
                                    Text("Regenerate Album Art")
                                }
                                .help("Recreate all album art thumbnails from the original artwork")
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text("Thumbnail Management")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .task {
                // Update cache size when view appears
                cacheSize = await ThumbnailCache.shared.getCacheSize()
                cachePath = await ThumbnailCache.shared.getCachePath()
            }
            
            if isRegenerating {
                Color(.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.0)
                    Text("Regenerating Album Art...")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Artwork")
        .alert("Clear Thumbnail Cache", isPresented: $showThumbnailCacheAlert) {
            Button("Clear", role: .destructive, action: clearThumbnailCache)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the thumbnail cache? This will require thumbnails to be regenerated when viewing albums.")
        }
        .alert("Regenerate Album Art", isPresented: $showRegenerateAlert) {
            Button("Regenerate", action: regenerateAlbumArt)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will regenerate all album art thumbnails. This may take a few moments.")
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func clearThumbnailCache() {
        isClearingThumbnails = true
        Task {
            // Clear file system cache
            await ThumbnailCache.shared.clearCache()
            
            // Clear in-memory image cache
            ImageCache.shared.removeAll()
            
            // Clear SwiftData thumbnails
            for track in libraryViewModel.tracks {
                track.thumbnail = nil
            }
            
            // Save changes to SwiftData
            try? modelContext.save()
            
            // Refresh the tracks to update the UI
            libraryViewModel.refreshTracks(context: modelContext)
            
            await MainActor.run {
                self.isClearingThumbnails = false
                print("Thumbnail cache cleared successfully.")
            }
        }
    }

    private func regenerateAlbumArt() {
        isRegenerating = true
        Task {
            await libraryViewModel.regenerateAlbumArt(context: modelContext)
            await MainActor.run {
                self.isRegenerating = false
                print("Album art regenerated successfully.")
            }
        }
    }
}
