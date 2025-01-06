//
//  GeneralSettingsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("autoLaunch") private var autoLaunch: Bool = false

    var body: some View {
        Form {
            Toggle("Launch app at startup", isOn: $autoLaunch)
            Toggle("Check for updates automatically", isOn: .constant(true)) // Example
        }
        .padding()
        .navigationTitle("General")
    }
}
