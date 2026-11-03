import SwiftUI

@main
struct FifteenFiveApp: App {
    @State private var timer = CycleTimer()

    var body: some Scene {
        #if os(macOS)
        // A Window as the primary scene quits the app on close, so no timer runs without UI.
        Window("15-5", id: "main") {
            ContentView(timer: timer)
        }
        .defaultSize(width: 420, height: 380)
        #else
        WindowGroup {
            ContentView(timer: timer)
        }
        #endif
    }
}
