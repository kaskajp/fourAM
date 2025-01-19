//
//  TimerManager.swift
//  fourAM
//
//  Created by Jonas on 2025-01-19.
//

import SwiftUI

class TimerManager: ObservableObject {
    private var timer: Timer?

    func debounce(interval: TimeInterval, action: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
        }
    }
}
