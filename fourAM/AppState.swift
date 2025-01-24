import SwiftUI

class AppState: ObservableObject {
    static let shared = AppState()
    var aboutWindow: NSWindow?
}
