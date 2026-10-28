import SwiftUI

/// Colours and reusable styles, same palette as the Avalonia app.
enum Theme {
    static let bg = Color(hex: 0x0D0E11)
    static let surface = Color(hex: 0x17191E)
    static let surface2 = Color(hex: 0x24272F)
    static let surface3 = Color(hex: 0x30343D)
    static let line = Color(hex: 0x2A2E36)
    static let ink = Color(hex: 0xF4F5F7)
    static let muted = Color(hex: 0x8D929C)
    static let accent = Color(hex: 0xC6F24E)
    static let accentPressed = Color(hex: 0xA9D332)
    static let accentSoft = Color(hex: 0xC6F24E, opacity: 0.15)
    static let onAccent = Color(hex: 0x0D0E11)
    static let warm = Color(hex: 0xFFB547)
    static let danger = Color(#colorLiteral(red: 1, green: 0.1991029382, blue: 0.2761334181, alpha: 0.575249566))
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Small caps label: "SCEGLI LO SPLIT DI OGGI".
struct SectionLabel: View {
    let text: String
    var size: CGFloat = 11
    var color = Theme.muted

    init(_ text: String, size: CGFloat = 11, color: Color = Theme.muted) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text).font(.system(size: size, weight: .semibold)).kerning(1.2).foregroundStyle(color)
    }
}

/// Big lime button ("Termina e salva").
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(configuration.isPressed ? Theme.accentPressed : Theme.accent,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Grey button with a shrink on press.
struct SoftButtonStyle: ButtonStyle {
    var background = Theme.surface2
    var foreground = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(configuration.isPressed ? Theme.surface3 : background, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Round 38pt button with a symbol ("−", "+", "‹").
struct RoundButton: View {
    let label: String
    var size: CGFloat = 38
    var fontSize: CGFloat = 20
    var background = Theme.surface2
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: fontSize, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(SoftButtonStyle(background: background))
    }
}

/// Small rounded "pill" button ("+ Serie", "Scarta").
struct PillButtonStyle: ButtonStyle {
    var background = Theme.surface2
    var foreground = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Theme.surface3 : background,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension View {
    /// Dark rounded card.
    func card(padding: CGFloat = 18, background: Color = Theme.surface) -> some View {
        self.padding(padding).background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Small grey tag ("4 serie").
    func chip(background: Color = Theme.surface2) -> some View {
        self.padding(.horizontal, 9).padding(.vertical, 5)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
