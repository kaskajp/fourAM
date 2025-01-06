//
//  fourAMApp.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import SwiftUI
import SwiftData

@main
struct fourAMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 1) Create a model container for our Track model
                .modelContainer(for: Track.self)
        }
    }
}
