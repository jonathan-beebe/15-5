import SwiftUI

@main
struct FifteenFiveApp: App {
    static let mainWindowID = "main"

    @State private var timer = CycleTimer()

    var body: some Scene {
        #if os(macOS)
        Window("15-5", id: Self.mainWindowID) {
            ContentView(timer: timer)
        }
        .defaultSize(width: 420, height: 380)

        MenuBarExtra {
            MenuBarMenu(timer: timer)
        } label: {
            MenuBarLabel(timer: timer)
        }
        #else
        WindowGroup {
            ContentView(timer: timer)
        }
        #endif
    }
}
