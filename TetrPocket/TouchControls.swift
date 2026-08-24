import SwiftUI

/// A press-and-hold button that fires keydown on touch-down and keyup on release.
/// TETR.IO handles DAS/ARR itself, so holding "left" auto-repeats correctly.
struct KeyButton: View {
    let label: String
    let gameKey: GameKey
    let proxy: WebViewProxy
    var size: CGFloat = 62

    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(pressed ? Color.white.opacity(0.45) : Color.white.opacity(0.16))
            )
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed {
                            pressed = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            proxy.sendKey(gameKey, down: true)
                        }
                    }
                    .onEnded { _ in
                        pressed = false
                        proxy.sendKey(gameKey, down: false)
                    }
            )
    }
}

struct TouchControls: View {
    @ObservedObject var proxy: WebViewProxy
    @State private var hidden = false

    var body: some View {
        ZStack {
            if !hidden {
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        // Left cluster: movement
                        VStack(spacing: 10) {
                            KeyButton(label: "⤓", gameKey: .hardDrop, proxy: proxy, size: 70)
                            HStack(spacing: 10) {
                                KeyButton(label: "◀", gameKey: .left, proxy: proxy)
                                KeyButton(label: "▼", gameKey: .softDrop, proxy: proxy)
                                KeyButton(label: "▶", gameKey: .right, proxy: proxy)
                            }
                        }
                        .padding(.leading, 24)

                        Spacer()

                        // Right cluster: rotation + hold
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                KeyButton(label: "H", gameKey: .hold, proxy: proxy, size: 52)
                                KeyButton(label: "180", gameKey: .rotate180, proxy: proxy, size: 52)
                            }
                            HStack(spacing: 10) {
                                KeyButton(label: "↺", gameKey: .rotateCCW, proxy: proxy, size: 70)
                                KeyButton(label: "↻", gameKey: .rotateCW, proxy: proxy, size: 70)
                            }
                        }
                        .padding(.trailing, 24)
                    }
                    .padding(.bottom, 20)
                }
            }

            // Top-corner utility strip
            VStack {
                HStack(spacing: 14) {
                    Spacer()
                    if !hidden {
                        SmallTapButton(label: "ESC") { proxy.sendKey(.escape, down: true); proxy.sendKey(.escape, down: false) }
                        SmallTapButton(label: "R") { proxy.sendKey(.retry, down: true); proxy.sendKey(.retry, down: false) }
                        SmallTapButton(label: "⟳") { proxy.reload() }
                    }
                    SmallTapButton(label: hidden ? "🎮" : "✕") {
                        withAnimation(.easeInOut(duration: 0.15)) { hidden.toggle() }
                    }
                }
                .padding(.top, 10)
                .padding(.trailing, 12)
                Spacer()
            }
        }
        .allowsHitTesting(true)
    }
}

struct SmallTapButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.14)))
        }
    }
}
