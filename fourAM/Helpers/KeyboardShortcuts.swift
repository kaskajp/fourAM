//
//  KeyboardShortcuts.swift
//  fourAM
//
//  Created by Jonas on 2025-01-13.
//

import SwiftUI
import AppKit

class GlobalKeyEventHandler {
    func setup(playbackManager: PlaybackManager) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.characters == " " {
                if playbackManager.isPlaying {
                    playbackManager.pause()
                } else {
                    playbackManager.resume()
                }
                return nil // Swallow the event
            }
            return event // Pass the event to the system
        }
    }
}
