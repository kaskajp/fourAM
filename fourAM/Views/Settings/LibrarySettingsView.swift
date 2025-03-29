import SwiftUI
import SwiftData

struct LibrarySettingsView: View {
    @AppStorage("defaultLibraryPath") private var defaultLibraryPath: String = ""
    @Environment(\.modelContext) private var modelContext // Access SwiftData context
    
    @State private var libraryActor: LibraryModelActor
    @State private var showAlert = false // Controls the alert for confirmation
    @State private var isClearing = false
    
    @EnvironmentObject var libraryViewModel: LibraryViewModel // Access ViewModel globally
    
    private var albumCount: Int {
        Set(libraryViewModel.tracks.map(\.album)).count
    }
    
    private var trackCount: Int {
        libraryViewModel.tracks.count
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    init(modelContext: ModelContext) {
        // Initialize the actor with the model context's container configuration
        let container = modelContext.container
        guard let configuration = container.configurations.first else {
            fatalError("No model configuration found")
        }
        self.libraryActor = LibraryModelActor(modelDescriptor: configuration)
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Library Statistics Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(trackCount) tracks")
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("\(albumCount) albums")
                                    .foregroundColor(.secondary)
                            }
                            .font(.callout)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text("Library Statistics")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Library Management Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            /*HStack {
                                TextField("Default Library Path", text: $defaultLibraryPath)
                                Button("Browse...") {
                                    chooseFolder()
                                }
                            }*/
                            
                            Button(role: .destructive) {
                                showAlert = true
                            } label: {
                                Text("Clear Library")
                            }
                            .help("Remove all tracks from your library")
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Text("Library Management")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            
            if isClearing {
                Color(.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2.0)
                    Text("Clearing Library...")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("This may take a few moments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Library")
        .alert("Clear Library", isPresented: $showAlert) {
            Button("Clear", role: .destructive, action: clearLibrary)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to clear the library? This action cannot be undone.")
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let selectedPath = panel.url?.path {
            defaultLibraryPath = selectedPath
        }
    }

    private func clearLibrary() {
        isClearing = true
        Task {
            do {
                try await libraryActor.deleteAllTracks()
                let remainingTracks = try await libraryActor.fetchAllTracks()
                await MainActor.run {
                    self.libraryViewModel.tracks = remainingTracks
                    self.isClearing = false
                    print("Library cleared successfully.")
                }
            } catch {
                await MainActor.run {
                    self.isClearing = false
                    print("Failed to clear library: \(error)")
                }
            }
        }
    }
}
