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

// MARK: - Layout model

/// One on-screen button. Position is stored as a fraction of the screen so a
/// layout survives rotation and moving between iPhone and iPad.
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
    @Published private(set) var adBlockEnabled: Bool
    @Published private(set) var hapticsEnabled: Bool

    private static let layoutKey = "tetrport.layout.v2"
    private static let adBlockKey = "tetrport.adblock.enabled"
    private static let hapticsKey = "tetrport.haptics.enabled"

    init() {
        let defaults = UserDefaults.standard
        adBlockEnabled = defaults.object(forKey: Self.adBlockKey) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Self.hapticsKey) as? Bool ?? true

        if let data = defaults.data(forKey: Self.layoutKey),
           let saved = try? JSONDecoder().decode([ControlButton].self, from: data),
           !saved.isEmpty {
            buttons = saved
        } else {
            buttons = Self.defaultLayout()
        }
    }

    // MARK: Persistence

    func save() {
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: Self.layoutKey)
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

    func resetLayout() {
        buttons = Self.defaultLayout()
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
        buttons[i].size = min(max(size, 40), 160)
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

    static func defaultLayout() -> [ControlButton] {
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let big: Double = pad ? 96 : 68        // hard drop / rotate
        let std: Double = pad ? 84 : 60        // movement
        let small: Double = pad ? 54 : 42      // utility
        let dx: Double = pad ? 0.072 : 0.088   // horizontal spacing
        let row1: Double = pad ? 0.86 : 0.84   // bottom row
        let row2: Double = pad ? 0.70 : 0.63   // row above

        let leftEdge: Double = pad ? 0.075 : 0.085
        let rightEdge: Double = 1.0 - leftEdge

        return [
            // Movement, left thumb
            ControlButton(key: .left,      x: leftEdge,          y: row1, size: std),
            ControlButton(key: .softDrop,  x: leftEdge + dx,     y: row1, size: std),
            ControlButton(key: .right,     x: leftEdge + dx * 2, y: row1, size: std),
            ControlButton(key: .hardDrop,  x: leftEdge + dx,     y: row2, size: big),

            // Rotation + hold, right thumb
            ControlButton(key: .rotateCCW, x: rightEdge - dx,    y: row1, size: big),
            ControlButton(key: .rotateCW,  x: rightEdge,         y: row1, size: big),
            ControlButton(key: .hold,      x: rightEdge - dx,    y: row2, size: std),
            ControlButton(key: .rotate180, x: rightEdge,         y: row2, size: std),

            // Utility, top right
            ControlButton(key: .escape,    x: 0.88,              y: 0.07, size: small, opacity: 0.55),
            ControlButton(key: .retry,     x: 0.94,              y: 0.07, size: small, opacity: 0.55),
        ]
    }
}
