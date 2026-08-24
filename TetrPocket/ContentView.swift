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

            GameWebView(proxy: proxy,
                        adBlockEnabled: store.adBlockEnabled,
                        zoom: store.boardZoom)
                .ignoresSafeArea()

            // Watches the screen shape so each device/orientation gets its own
            // control arrangement. Kept separate from the overlay so it keeps
            // working while the overlay is hidden.
            GeometryReader { geo in
                Color.clear
                    .onAppear { store.activate(.current(size: geo.size)) }
                    .onChange(of: geo.size) { _, newSize in
                        store.activate(.current(size: newSize))
                    }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

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
        // Coming back from the background can leave the session deactivated and
        // contexts suspended, so re-assert both.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)) { _ in
            AudioSession.reactivate()
            proxy.unlockAudio()
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
