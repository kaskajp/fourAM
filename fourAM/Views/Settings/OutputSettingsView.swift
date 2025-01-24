import SwiftUI

struct OutputSettingsView: View {
    @AppStorage("audioDevice") private var audioDevice: String = "Default Device"
    let devices = ["Default Device", "External Speaker", "Headphones"]

    var body: some View {
        Form {
            Picker("Audio Output Device", selection: $audioDevice) {
                ForEach(devices, id: \.self) { device in
                    Text(device)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .navigationTitle("Output")
    }
}
