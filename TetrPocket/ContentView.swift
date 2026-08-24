import SwiftUI
import Combine
import GameController

struct ContentView: View {
    @StateObject private var store = LayoutStore()
    @StateObject private var proxy = WebViewProxy()

    /// Set once when a hardware keyboard first appears, so the auto-hide doesn't
    /// keep overriding a manual choice afterwards.
    @State private var didAutoHideForKeyboard = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GameWebView(proxy: proxy, adBlockEnabled: store.adBlockEnabled)
                .ignoresSafeArea()

            if !store.overlayHidden {
                ControlOverlay(store: store, proxy: proxy)
                    .ignoresSafeArea()
            }

            if store.isEditing {
                EditPanel(store: store)
            }

            VStack {
                HStack {
                    HUDStrip(store: store, proxy: proxy)
                    Spacer()
                }
                Spacer()
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            store.keyboardConnected = (GCKeyboard.coalesced != nil)
            if store.keyboardConnected { autoHideForKeyboard() }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        // A hardware keyboard talks to the page directly, so the overlay is just
        // in the way — tuck it away the first time one shows up. The controller
        // icon in the HUD brings it back.
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)) { _ in
            store.keyboardConnected = true
            autoHideForKeyboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCKeyboardDidDisconnect)) { _ in
            store.keyboardConnected = false
        }
    }

    private func autoHideForKeyboard() {
        guard !didAutoHideForKeyboard, !store.isEditing else { return }
        didAutoHideForKeyboard = true
        store.overlayHidden = true
    }
}

#Preview {
    ContentView()
}
