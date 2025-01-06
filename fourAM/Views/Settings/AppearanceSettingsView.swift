//
//  AppearanceSettingsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("theme") private var theme: String = "System Default"
    let themes = ["System Default", "Light", "Dark"]

    var body: some View {
        Form {
            Picker("Theme", selection: $theme) {
                ForEach(themes, id: \.self) { theme in
                    Text(theme)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .navigationTitle("Appearance")
    }
}
