import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
    // Warm gray scale (tailwind.config.js) + oklch accents (computed → sRGB)
    static let warm50  = Color(hex: 0xFAF9F5)
    static let warm100 = Color(hex: 0xF0F0EB)
    static let warm200 = Color(hex: 0xE5E5E0)
    static let warm300 = Color(hex: 0xCFCFC8)
    static let warm400 = Color(hex: 0x999996)
    static let warm500 = Color(hex: 0x666664)
    static let warm600 = Color(hex: 0x444442)
    static let warm700 = Color(hex: 0x2B2B29)
    static let warm900 = Color(hex: 0x1A1A1A)
    static let appBg     = Color(hex: 0xF8F5EF)   // oklch(97% .008 80)
    static let gold      = Color(hex: 0xCD9A50)   // oklch(72% .11 75)
    static let goldSoft  = Color(hex: 0xE9CCA6)   // oklch(86% .06 75)
    static let goldDeep  = Color(hex: 0xA0600B)   // oklch(55% .12 65)
    static let karaokeGreen = Color(hex: 0x00BC6D)
    static let heartRed  = Color(hex: 0xE0245E)
    static let heartIdle = Color(hex: 0xC8C8C2)
    static let red50  = Color(hex: 0xFEF2F2)
    static let red100 = Color(hex: 0xFEE2E2)
    static let red600 = Color(hex: 0xDC2626)
}

// MARK: - Fonts (exact PostScript names of bundled faces)

extension Font {
    /// Quran verse + translation + tooltip — "Thmanyah Serif Display".
    static func thmanyah(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light:  name = "thmanyahserifdisplay-Light"
        case .medium: name = "thmanyahserifdisplay-Medium"
        case .bold:   name = "thmanyahserifdisplay-Bold"
        case .black, .heavy: name = "thmanyahserifdisplay-Black"
        default:      name = "thmanyahserifdisplay-Regular"
        }
        return .custom(name, fixedSize: size)
    }
    /// Display headings — font-resolide → Arsenica.
    static func resolide(_ size: CGFloat, bold: Bool = true) -> Font {
        .custom(bold ? "ArsenicaTrial-Bold" : "ArsenicaTrial-Regular", fixedSize: size)
    }
    /// font-serif → Playfair Display.
    static func playfair(_ size: CGFloat, bold: Bool = false, italic: Bool = false) -> Font {
        let n = bold ? (italic ? "PlayfairDisplay-BoldItalic" : "PlayfairDisplay-Bold")
                     : (italic ? "PlayfairDisplay-Italic" : "PlayfairDisplay-Regular")
        return .custom(n, fixedSize: size)
    }
    /// font-inter / font-sans (300/400/500/600/700).
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .light:    name = "Inter-Light"
        case .medium:   name = "Inter-Medium"
        case .semibold: name = "Inter-SemiBold"
        case .bold:     name = "Inter-Bold"
        default:        name = "Inter-Regular"
        }
        return .custom(name, fixedSize: size)
    }
    /// font-mono (tailwind default mono → SF Mono).
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Elevation (tailwind boxShadow card/dropdown/overlay)

extension View {
    func shadowCard() -> some View {
        shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 4)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    func shadowDropdown() -> some View {
        shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 12)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 4)
    }
    func shadowOverlay() -> some View {
        shadow(color: .black.opacity(0.15), radius: 28, x: 0, y: 28)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 8)
    }
}

/// Honors prefers-reduced-motion (the PWA's @media query).
func anim(_ a: Animation) -> Animation? {
    UIAccessibility.isReduceMotionEnabled ? nil : a
}
