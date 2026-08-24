import SwiftUI

@main
struct TetrPocketApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .ignoresSafeArea()
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    // Keep the screen awake during play
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
    }
}
