import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("autoLaunch") private var autoLaunch: Bool = false
    
    // Use a local state to track if we're in the process of updating
    @State private var isUpdating = false

    var body: some View {
        Form {
            Toggle("Launch app at startup", isOn: $autoLaunch)
                .onChange(of: autoLaunch) { _, newValue in
                    guard !isUpdating else { return }
                    
                    isUpdating = true
                    LaunchAtLoginManager.setLaunchAtLogin(enabled: newValue)
                    isUpdating = false
                }
        }
        .padding()
        .navigationTitle("General")
        .onAppear {
            // Synchronize UI state with actual login item status when available
            if #available(macOS 13.0, *) {
                isUpdating = true
                autoLaunch = LaunchAtLoginManager.isLaunchAtLoginEnabled()
                isUpdating = false
            }
        }
    }
}
