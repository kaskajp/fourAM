import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("Logo")
                .resizable()
                .frame(width: 100, height: 100)
                .padding(.top, 10)
            
            Text("4AM")
                .font(.title)
                .fontWeight(.bold)
            
            Text("A native macOS music player for local music libraries.")
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            
            Text(appVersion)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("This app is licensed under the MPL-2.0 license.")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Link("View on GitHub", destination: URL(string: "https://github.com/kaskajp/fourAM")!)
                .font(.footnote)
                .foregroundColor(.blue)
        }
        .padding()
        .frame(width: 400, height: 350)
    }
    
    private var appIcon: NSImage? {
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let lastIconName = iconFiles.last else {
            return nil
        }
        return NSImage(named: lastIconName)
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown Version"
    }
}
