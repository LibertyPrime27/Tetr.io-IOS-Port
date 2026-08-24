import SwiftUI

/// Settings sheet, shown while arranging controls: board zoom, then per-button
/// size and fade for whichever button is selected.
struct EditPanel: View {
    @ObservedObject var store: LayoutStore

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                // Layouts are stored per device class and orientation, so name the
                // one being edited.
                Text("EDITING \(store.slot.label.uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.0)

                // --- board zoom (applies live) ---
                Text("BOARD ZOOM")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.cyan)
                    .tracking(1.2)

                SliderRow(icon: "plus.magnifyingglass",
                          value: store.boardZoom * 100,
                          range: (LayoutStore.zoomRange.lowerBound * 100)...(LayoutStore.zoomRange.upperBound * 100),
                          unit: "%") { newValue in
                    store.setZoom(newValue / 100)
                } onCommit: {
                    store.commitZoom()
                }

                Text("Bigger board also renders fewer pixels, so this can help frame rate.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Color.white.opacity(0.15))

                // --- selected button ---
                if let button = store.selectedButton {
                    Text(button.key.title.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.cyan)
                        .tracking(1.2)

                    SliderRow(icon: "arrow.up.left.and.arrow.down.right",
                              value: button.size, range: 40...170, unit: "pt") { newValue in
                        store.setSize(button.id, newValue)
                    } onCommit: {
                        store.save()
                    }

                    SliderRow(icon: "circle.lefthalf.filled",
                              value: button.opacity * 100, range: 5...100, unit: "%") { newValue in
                        store.setOpacity(button.id, newValue / 100)
                    } onCommit: {
                        store.save()
                    }
                } else {
                    Text("DRAG ANY BUTTON TO MOVE IT")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1.2)
                    Text("Tap one to resize or fade it.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                Divider().overlay(Color.white.opacity(0.15))

                Toggle(isOn: Binding(get: { store.hapticsEnabled },
                                     set: { store.setHaptics($0) })) {
                    Label("Haptics", systemImage: "hand.tap.fill")
                        .font(.system(size: 13, design: .rounded))
                }
                .tint(.cyan)

                Toggle(isOn: Binding(get: { store.adBlockEnabled },
                                     set: { store.setAdBlock($0) })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Label("Block ads", systemImage: "shield.lefthalf.filled")
                            .font(.system(size: 13, design: .rounded))
                        Text("Applies on next launch")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .tint(.cyan)

                Button {
                    store.resetLayout()
                } label: {
                    Label("Reset layout", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.white)
            .padding(14)
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.bottom, 24)
        }
    }
}

private struct SliderRow: View {
    let icon: String
    let value: Double
    let range: ClosedRange<Double>
    let unit: String
    let onChange: (Double) -> Void
    let onCommit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 18)

            Slider(value: Binding(get: { value }, set: { onChange($0) }),
                   in: range,
                   onEditingChanged: { editing in if !editing { onCommit() } })
                .tint(.cyan)

            Text("\(Int(value))\(unit)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 42, alignment: .trailing)
        }
    }
}
