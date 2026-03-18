import SwiftUI

extension Color {
    /// Initialise from a hex string such as "#8B5CF6" or "8B5CF6"
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Returns a "#RRGGBB" hex string representation
    func toHex() -> String {
        let resolved = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(min(r, 1) * 255)
        let gi = Int(min(g, 1) * 255)
        let bi = Int(min(b, 1) * 255)
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    // MARK: - Preset swatches

    static let habitPresets: [Color] = [
        Color(hex: "#8B5CF6") ?? .purple,   // violet
        Color(hex: "#6366F1") ?? .indigo,   // indigo
        Color(hex: "#EC4899") ?? .pink,     // pink
        Color(hex: "#F97316") ?? .orange,   // orange
        Color(hex: "#EF4444") ?? .red,      // red
        Color(hex: "#0EA5E9") ?? .cyan,     // sky
        Color(hex: "#F59E0B") ?? .yellow,   // amber
        Color(hex: "#84CC16") ?? .green,    // lime
    ]

    static let goalPresets: [Color] = [
        Color(hex: "#10B981") ?? .green,    // emerald
        Color(hex: "#14B8A6") ?? .teal,     // teal
        Color(hex: "#06B6D4") ?? .cyan,     // cyan
        Color(hex: "#22C55E") ?? .green,    // green
        Color(hex: "#3B82F6") ?? .blue,     // blue
        Color(hex: "#A78BFA") ?? .purple,   // violet
        Color(hex: "#FB923C") ?? .orange,   // orange
        Color(hex: "#F43F5E") ?? .red,      // rose
    ]
}
