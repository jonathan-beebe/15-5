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
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 380)
        #if DEBUG
        .commands { DeveloperCommands() }
        #endif

        MenuBarExtra {
            MenuBarMenu(timer: timer)
        } label: {
            MenuBarLabel(timer: timer)
        }

        #if DEBUG
        Window("Developer", id: DeveloperMenu.windowID) {
            DeveloperMenu(timer: timer)
        }
        .windowResizability(.contentSize)

        Window("Gradient Preview", id: GradientPreview.windowID) {
            GradientPreview()
        }
        .defaultSize(width: 800, height: 500)
        #endif
        #else
        WindowGroup {
            ContentView(timer: timer)
        }
        #endif
    }
}
