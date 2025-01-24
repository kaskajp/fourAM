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
