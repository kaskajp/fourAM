//
//  AppearanceSettingsView.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("theme") private var theme: String = "System Default"
    @AppStorage("coverImageSize") private var coverImageSize: Double = 100.0 // Default size

    let themes = ["System Default", "Light", "Dark"]

    var body: some View {
        Form {
            // Theme Picker
            /*Picker("Theme", selection: $theme) {
                ForEach(themes, id: \.self) { theme in
                    Text(theme)
                }
            }
            .pickerStyle(SegmentedPickerStyle())*/

            // Cover Image Size Slider
            //Section("Album Cover Size") {
                VStack(alignment: .leading) {
                    Slider(value: $coverImageSize, in: 50...200, step: 10) {
                        Text("Cover Image Size")
                    }
                    Text("Size: \(Int(coverImageSize)) px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            //}
        }
        .padding()
        .navigationTitle("Appearance")
    }
}
