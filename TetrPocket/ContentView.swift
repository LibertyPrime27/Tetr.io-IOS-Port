import SwiftUI

struct ContentView: View {
    @StateObject private var proxy = WebViewProxy()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GameWebView(proxy: proxy)
                .ignoresSafeArea()
            TouchControls(proxy: proxy)
        }
        .statusBarHidden(true)
    }
}

#Preview {
    ContentView()
}
