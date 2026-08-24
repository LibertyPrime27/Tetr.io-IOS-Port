import SwiftUI

@main
struct TetrPocketApp: App {
    init() {
        // Do this before the web view exists so the first sound the page makes
        // lands on an already-playing session.
        AudioSession.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .ignoresSafeArea()
        }
    }
}
