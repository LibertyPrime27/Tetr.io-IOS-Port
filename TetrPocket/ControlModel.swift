import SwiftUI

// MARK: - Keys

/// A key the overlay can press. TETR.IO reads `event.code`, so that field matters most.
enum GameKey: String, Codable, CaseIterable, Identifiable {
    case left, right, softDrop, hardDrop, rotateCW, rotateCCW, rotate180, hold, escape, retry

    var id: String { rawValue }

    /// Glyph drawn on the button.
    var glyph: String {
        switch self {
        case .left:      return "\u{25C0}"   // ◀
        case .right:     return "\u{25B6}"   // ▶
        case .softDrop:  return "\u{25BC}"   // ▼
        case .hardDrop:  return "\u{2913}"   // ⤓
        case .rotateCW:  return "\u{21BB}"   // ↻
        case .rotateCCW: return "\u{21BA}"   // ↺
        case .rotate180: return "180"
        case .hold:      return "H"
        case .escape:    return "ESC"
        case .retry:     return "R"
        }
    }

    /// Human-readable name for the edit panel.
    var title: String {
        switch self {
        case .left:      return "Move left"
        case .right:     return "Move right"
        case .softDrop:  return "Soft drop"
        case .hardDrop:  return "Hard drop"
        case .rotateCW:  return "Rotate CW"
        case .rotateCCW: return "Rotate CCW"
        case .rotate180: return "Rotate 180"
        case .hold:      return "Hold"
        case .escape:    return "Menu / Esc"
        case .retry:     return "Retry"
        }
    }

    /// TETR.IO's default binding for this action.
    var code: String {
        switch self {
        case .left:      return "ArrowLeft"
        case .right:     return "ArrowRight"
        case .softDrop:  return "ArrowDown"
        case .hardDrop:  return "Space"
        case .rotateCW:  return "ArrowUp"
        case .rotateCCW: return "KeyZ"
        case .rotate180: return "KeyA"
        case .hold:      return "KeyC"
        case .escape:    return "Escape"
        case .retry:     return "KeyR"
        }
    }

    var keyValue: String {
        switch self {
        case .left:      return "ArrowLeft"
        case .right:     return "ArrowRight"
        case .softDrop:  return "ArrowDown"
        case .hardDrop:  return " "
        case .rotateCW:  return "ArrowUp"
        case .rotateCCW: return "z"
        case .rotate180: return "a"
        case .hold:      return "c"
        case .escape:    return "Escape"
        case .retry:     return "r"
        }
    }

    /// Legacy keyCode, for anything still reading it.
    var keyCode: Int {
        switch self {
        case .left:      return 37
        case .right:     return 39
        case .softDrop:  return 40
        case .hardDrop:  return 32
        case .rotateCW:  return 38
        case .rotateCCW: return 90
        case .rotate180: return 65
        case .hold:      return 67
        case .escape:    return 27
        case .retry:     return 82
        }
    }

    /// Tap-and-release keys (menu actions) vs press-and-hold keys (gameplay).
    var isTapOnly: Bool {
        switch self {
        case .escape, .retry: return true
        default:              return false
        }
    }
}

// MARK: - Layout slots

/// Positions are stored as screen fractions, which survives resolution changes
/// but *not* aspect-ratio changes: three buttons spaced 0.09 apart sit 75pt
/// apart on a landscape phone and 35pt apart in portrait — overlapping. So each
/// device class and orientation keeps its own arrangement.
enum LayoutSlot: String, CaseIterable {
    case phonePortrait, phoneLandscape, padPortrait, padLandscape

    static func current(size: CGSize) -> LayoutSlot {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let isLandscape = size.width >= size.height
        switch (isPad, isLandscape) {
        case (true, true):   return .padLandscape
        case (true, false):  return .padPortrait
        case (false, true):  return .phoneLandscape
        case (false, false): return .phonePortrait
        }
    }

    var isPad: Bool { self == .padPortrait || self == .padLandscape }

    /// Shown in the edit panel so it's obvious which arrangement you're changing.
    var label: String {
        switch self {
        case .phonePortrait:  return "iPhone \u{00B7} Portrait"
        case .phoneLandscape: return "iPhone \u{00B7} Landscape"
        case .padPortrait:    return "iPad \u{00B7} Portrait"
        case .padLandscape:   return "iPad \u{00B7} Landscape"
        }
    }
}

// MARK: - Layout model

/// One on-screen button, positioned as a fraction of the screen.
struct ControlButton: Identifiable, Codable, Equatable {
    var id: UUID
    var key: GameKey
    var x: Double       // 0...1, center
    var y: Double       // 0...1, center
    var size: Double    // points
    var opacity: Double // 0.05...1

    init(id: UUID = UUID(), key: GameKey, x: Double, y: Double, size: Double, opacity: Double = 0.9) {
        self.id = id
        self.key = key
        self.x = x
        self.y = y
        self.size = size
        self.opacity = opacity
    }
}

// MARK: - Store

final class LayoutStore: ObservableObject {
    @Published var buttons: [ControlButton]
    @Published var isEditing: Bool = false
    @Published var selected: UUID?
    @Published var overlayHidden: Bool = false
    @Published var keyboardConnected: Bool = false
    @Published private(set) var slot: LayoutSlot
    @Published private(set) var adBlockEnabled: Bool
    @Published private(set) var hapticsEnabled: Bool

    /// Every slot's arrangement, keyed by `LayoutSlot.rawValue`.
    private var stored: [String: [ControlButton]]

    private static let layoutsKey = "tetrport.layouts.v3"
    private static let adBlockKey = "tetrport.adblock.enabled"
    private static let hapticsKey = "tetrport.haptics.enabled"

    init() {
        let defaults = UserDefaults.standard
        adBlockEnabled = defaults.object(forKey: Self.adBlockKey) as? Bool ?? true

        // iPads have no haptic engine, so the feedback is dead weight there.
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        hapticsEnabled = defaults.object(forKey: Self.hapticsKey) as? Bool ?? !isPad

        let decoded: [String: [ControlButton]]
        if let data = defaults.data(forKey: Self.layoutsKey),
           let map = try? JSONDecoder().decode([String: [ControlButton]].self, from: data) {
            decoded = map
        } else {
            decoded = [:]
        }
        stored = decoded

        // Start on the slot matching the current screen; corrected on first layout pass.
        let startSlot: LayoutSlot = isPad ? .padLandscape : .phoneLandscape
        slot = startSlot
        buttons = decoded[startSlot.rawValue] ?? Self.defaultLayout(for: startSlot)
    }

    // MARK: Slots

    /// Switch to the arrangement for this screen shape, stashing the current one.
    func activate(_ newSlot: LayoutSlot) {
        guard newSlot != slot else { return }
        stored[slot.rawValue] = buttons
        slot = newSlot
        buttons = stored[newSlot.rawValue] ?? Self.defaultLayout(for: newSlot)
        selected = nil
    }

    // MARK: Persistence

    func save() {
        stored[slot.rawValue] = buttons
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.layoutsKey)
        }
    }

    func setAdBlock(_ enabled: Bool) {
        adBlockEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.adBlockKey)
    }

    func setHaptics(_ enabled: Bool) {
        hapticsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.hapticsKey)
    }

    /// Reset only the arrangement currently on screen.
    func resetLayout() {
        buttons = Self.defaultLayout(for: slot)
        selected = nil
        save()
    }

    // MARK: Mutation

    func index(of id: UUID) -> Int? {
        buttons.firstIndex { $0.id == id }
    }

    func move(_ id: UUID, toX x: Double, y: Double) {
        guard let i = index(of: id) else { return }
        buttons[i].x = min(max(x, 0.03), 0.97)
        buttons[i].y = min(max(y, 0.04), 0.96)
    }

    func setSize(_ id: UUID, _ size: Double) {
        guard let i = index(of: id) else { return }
        buttons[i].size = min(max(size, 40), 170)
    }

    func setOpacity(_ id: UUID, _ opacity: Double) {
        guard let i = index(of: id) else { return }
        buttons[i].opacity = min(max(opacity, 0.05), 1.0)
    }

    var selectedButton: ControlButton? {
        guard let id = selected else { return nil }
        return buttons.first { $0.id == id }
    }

    // MARK: Defaults

    /// Tuned per screen shape: spacing is chosen so buttons clear each other on
    /// the narrow axis, and sizes follow the touch target the device deserves.
    static func defaultLayout(for slot: LayoutSlot) -> [ControlButton] {
        let big: Double, std: Double, small: Double
        let dx: Double, edge: Double, row1: Double, row2: Double

        switch slot {
        case .padLandscape:
            big = 96; std = 86; small = 54
            dx = 0.064; edge = 0.072; row1 = 0.855; row2 = 0.700
        case .padPortrait:
            big = 96; std = 86; small = 54
            dx = 0.086; edge = 0.095; row1 = 0.880; row2 = 0.775
        case .phoneLandscape:
            big = 66; std = 58; small = 40
            dx = 0.076; edge = 0.072; row1 = 0.800; row2 = 0.540
        case .phonePortrait:
            big = 62; std = 56; small = 40
            dx = 0.170; edge = 0.130; row1 = 0.895; row2 = 0.800
        }

        let rightEdge = 1.0 - edge

        return [
            // Movement, left thumb
            ControlButton(key: .left,      x: edge,             y: row1, size: std),
            ControlButton(key: .softDrop,  x: edge + dx,        y: row1, size: std),
            ControlButton(key: .right,     x: edge + dx * 2,    y: row1, size: std),
            ControlButton(key: .hardDrop,  x: edge + dx,        y: row2, size: big),

            // Rotation + hold, right thumb
            ControlButton(key: .rotateCCW, x: rightEdge - dx,   y: row1, size: big),
            ControlButton(key: .rotateCW,  x: rightEdge,        y: row1, size: big),
            ControlButton(key: .hold,      x: rightEdge - dx,   y: row2, size: std),
            ControlButton(key: .rotate180, x: rightEdge,        y: row2, size: std),

            // Utility, top right
            ControlButton(key: .escape,    x: 0.88,             y: 0.06, size: small, opacity: 0.5),
            ControlButton(key: .retry,     x: 0.945,            y: 0.06, size: small, opacity: 0.5),
        ]
    }
}
