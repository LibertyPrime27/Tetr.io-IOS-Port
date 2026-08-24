import SwiftUI

// MARK: - Haptics

/// One prepared generator, reused. Building a fresh generator per press costs
/// more than the feedback is worth in a game that takes several inputs a second.
enum Haptics {
    private static let light: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.prepare()
        return g
    }()

    static func tick(enabled: Bool) {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.55)
        light.prepare()
    }
}

// MARK: - One button

struct ControlButtonView: View {
    let button: ControlButton
    @ObservedObject var store: LayoutStore
    @ObservedObject var proxy: WebViewProxy
    let canvas: CGSize

    @State private var pressed = false
    @State private var dragOrigin: CGPoint?

    private var isSelected: Bool { store.selected == button.id && store.isEditing }

    private var glyphScale: Double {
        switch button.key {
        case .rotate180, .escape: return 0.26
        case .hold, .retry:       return 0.40
        default:                  return 0.44
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(pressed ? 0.44 : 0.15))
            Circle()
                .strokeBorder(isSelected ? Color.cyan : Color.white.opacity(0.30),
                              lineWidth: isSelected ? 3 : 1)
            Text(button.key.glyph)
                .font(.system(size: button.size * glyphScale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(width: button.size, height: button.size)
        // In edit mode force buttons visible so you can find the faint ones.
        .opacity(store.isEditing ? max(button.opacity, 0.8) : button.opacity)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if store.isEditing {
                        if dragOrigin == nil {
                            dragOrigin = CGPoint(x: button.x, y: button.y)
                            store.selected = button.id
                        }
                        guard let origin = dragOrigin, canvas.width > 0, canvas.height > 0 else { return }
                        store.move(button.id,
                                   toX: origin.x + value.translation.width / canvas.width,
                                   y: origin.y + value.translation.height / canvas.height)
                    } else if !pressed {
                        pressed = true
                        Haptics.tick(enabled: store.hapticsEnabled)
                        if button.key.isTapOnly {
                            proxy.tap(button.key)
                        } else {
                            proxy.send(button.key, down: true)
                        }
                    }
                }
                .onEnded { _ in
                    if store.isEditing {
                        dragOrigin = nil
                        store.save()
                    } else {
                        pressed = false
                        if !button.key.isTapOnly {
                            proxy.send(button.key, down: false)
                        }
                    }
                }
        )
    }
}

// MARK: - Overlay

struct ControlOverlay: View {
    @ObservedObject var store: LayoutStore
    @ObservedObject var proxy: WebViewProxy

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if store.isEditing {
                    Color.black.opacity(0.45).ignoresSafeArea()
                }

                ForEach(store.buttons) { button in
                    ControlButtonView(button: button, store: store, proxy: proxy, canvas: geo.size)
                        .position(x: button.x * geo.size.width,
                                  y: button.y * geo.size.height)
                }
            }
        }
    }
}

// MARK: - HUD

/// Small always-available strip: edit layout, hide the overlay, reload the page.
struct HUDStrip: View {
    @ObservedObject var store: LayoutStore
    @ObservedObject var proxy: WebViewProxy

    var body: some View {
        HStack(spacing: 8) {
            if store.overlayHidden {
                Chip(icon: "gamecontroller.fill", label: nil) {
                    store.overlayHidden = false
                }
            } else {
                Chip(icon: "slider.horizontal.3", label: store.isEditing ? "Done" : nil) {
                    if store.isEditing {
                        store.isEditing = false
                        store.selected = nil
                        store.save()
                    } else {
                        proxy.releaseAll()
                        store.isEditing = true
                    }
                }
                if !store.isEditing {
                    Chip(icon: "eye.slash.fill", label: nil) {
                        proxy.releaseAll()
                        store.overlayHidden = true
                    }
                    Chip(icon: "arrow.clockwise", label: nil) {
                        proxy.reload()
                    }
                }
            }
        }
        .padding(.leading, 12)
        .padding(.top, 8)
    }
}

struct Chip: View {
    let icon: String
    let label: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                if let label {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
