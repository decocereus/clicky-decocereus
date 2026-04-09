//
//  ClickyTheme.swift
//  leanring-buddy
//
//  Theme tokens translated from a Tailwind-style design config so Studio and
//  the companion panel can share one variable-scoped visual system.
//

import AppKit
import SwiftUI

enum ClickyThemePreset: String, CaseIterable, Identifiable {
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    var theme: ClickyTheme {
        switch self {
        case .dark:
            return ClickyTheme(
                background: Color(hex: "#121212"),
                foreground: Color(hex: "#FBF8F5"),
                card: Color(hex: "#1F1F1F"),
                cardForeground: Color(hex: "#FBF8F5"),
                popover: Color(hex: "#1F1F1F"),
                popoverForeground: Color(hex: "#FBF8F5"),
                primary: Color(hex: "#53CFAF"),
                primaryForeground: .white,
                secondary: Color(hex: "#2A2A2A"),
                secondaryForeground: Color(hex: "#FBF8F5"),
                muted: Color(hex: "#1F1C1D"),
                mutedForeground: Color(hex: "#7A7778"),
                accent: Color(hex: "#53CFAF"),
                accentForeground: .white,
                destructive: Color(hex: "#86002D"),
                destructiveForeground: .white,
                border: Color(hex: "#333333"),
                input: Color(hex: "#1F1F1F"),
                ring: Color(hex: "#53CFAF"),
                sidebar: Color(hex: "#121212"),
                sidebarForeground: Color(hex: "#FBF8F5"),
                sidebarPrimary: Color(hex: "#53CFAF"),
                sidebarPrimaryForeground: .white,
                sidebarAccent: Color(hex: "#53CFAF"),
                sidebarAccentForeground: .white,
                sidebarBorder: Color(hex: "#333333"),
                sidebarRing: Color(hex: "#53CFAF"),
                radius: 16,
                trackingNormal: -0.01,
                glowA: Color(hex: "#0F2C26"),
                glowB: Color(hex: "#172120")
            )
        case .light:
            return ClickyTheme(
                background: Color(hex: "#FBF8F5"),
                foreground: .black,
                card: Color(hex: "#FBF8F5"),
                cardForeground: .black,
                popover: .white,
                popoverForeground: .black,
                primary: Color(hex: "#7A5EFF"),
                primaryForeground: .white,
                secondary: Color(hex: "#A694FF"),
                secondaryForeground: .black,
                muted: Color(hex: "#F2EEE8"),
                mutedForeground: Color(hex: "#666666"),
                accent: Color(hex: "#7A5EFF"),
                accentForeground: .white,
                destructive: Color(hex: "#FF5E93"),
                destructiveForeground: .white,
                border: .black,
                input: .white,
                ring: Color(hex: "#7A5EFF"),
                sidebar: Color(hex: "#121212"),
                sidebarForeground: .white,
                sidebarPrimary: Color(hex: "#7A5EFF"),
                sidebarPrimaryForeground: .white,
                sidebarAccent: Color(hex: "#1F1F1F"),
                sidebarAccentForeground: .white,
                sidebarBorder: Color(hex: "#333333"),
                sidebarRing: Color(hex: "#7A5EFF"),
                radius: 16,
                trackingNormal: -0.01,
                glowA: Color(hex: "#E4DBFF"),
                glowB: Color(hex: "#F5EFE7")
            )
        }
    }
}

struct ClickyTheme: Equatable {
    let background: Color
    let foreground: Color
    let card: Color
    let cardForeground: Color
    let popover: Color
    let popoverForeground: Color
    let primary: Color
    let primaryForeground: Color
    let secondary: Color
    let secondaryForeground: Color
    let muted: Color
    let mutedForeground: Color
    let accent: Color
    let accentForeground: Color
    let destructive: Color
    let destructiveForeground: Color
    let border: Color
    let input: Color
    let ring: Color
    let sidebar: Color
    let sidebarForeground: Color
    let sidebarPrimary: Color
    let sidebarPrimaryForeground: Color
    let sidebarAccent: Color
    let sidebarAccentForeground: Color
    let sidebarBorder: Color
    let sidebarRing: Color
    let radius: CGFloat
    let trackingNormal: CGFloat
    let glowA: Color
    let glowB: Color

    // Compatibility aliases for existing view code.
    var textPrimary: Color { foreground }
    var textSecondary: Color { foreground.opacity(0.82) }
    var textMuted: Color { mutedForeground }
    var accentStrong: Color { primary }
    var accentSoft: Color { secondary }
    var strokeStrong: Color { border.opacity(0.9) }
    var strokeSoft: Color { border.opacity(0.55) }
    var success: Color { accent }
    var warning: Color { Color(hex: "#DFBB7B") }
}

private struct ClickyThemeKey: EnvironmentKey {
    static let defaultValue = ClickyThemePreset.dark.theme
}

extension EnvironmentValues {
    var clickyTheme: ClickyTheme {
        get { self[ClickyThemeKey.self] }
        set { self[ClickyThemeKey.self] = newValue }
    }
}

extension View {
    func clickyTheme(_ theme: ClickyTheme) -> some View {
        environment(\.clickyTheme, theme)
    }
}

enum ClickyTypography {
    static func brand(size: CGFloat) -> Font {
        resolvedFont(
            candidates: ["PlayfairDisplayRoman-SemiBold", "PlayfairDisplay-Regular", "Playfair Display"],
            size: size,
            fallback: .system(size: size, weight: .regular, design: .serif)
        )
    }

    static func display(size: CGFloat) -> Font {
        resolvedFont(
            candidates: ["PlayfairDisplay-Regular", "Playfair Display"],
            size: size,
            fallback: .system(size: size, weight: .regular, design: .serif)
        )
    }

    static func section(size: CGFloat) -> Font {
        resolvedFont(
            candidates: ["PlayfairDisplayRoman-SemiBold", "PlayfairDisplayRoman-Medium", "Playfair Display"],
            size: size,
            fallback: .system(size: size, weight: .semibold, design: .serif)
        )
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolvedFont(candidates: sansCandidates(for: weight), size: size, fallback: .system(size: size, weight: weight, design: .default))
    }

    static func serif(size: CGFloat) -> Font {
        resolvedFont(
            candidates: ["PlayfairDisplay-Regular", "Playfair Display", "Iowan Old Style", "Baskerville"],
            size: size,
            fallback: .system(size: size, weight: .regular, design: .serif)
        )
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        resolvedFont(candidates: monoCandidates(for: weight), size: size, fallback: .system(size: size, weight: weight, design: .monospaced))
    }

    private static func resolvedFont(candidates: [String], size: CGFloat, fallback: Font) -> Font {
        for candidate in candidates {
            if let font = NSFont(name: candidate, size: size) {
                return Font(font)
            }
        }

        return fallback
    }

    private static func sansCandidates(for weight: Font.Weight) -> [String] {
        switch weight {
        case .semibold, .bold:
            return ["Poppins-SemiBold", "Poppins-Medium", "Poppins"]
        case .medium:
            return ["Poppins-Medium", "Poppins-Regular", "Poppins"]
        default:
            return ["Poppins-Regular", "Poppins"]
        }
    }

    private static func monoCandidates(for weight: Font.Weight) -> [String] {
        switch weight {
        case .semibold, .bold:
            return ["JetBrainsMonoRoman-Medium", "JetBrainsMono-Regular", "JetBrains Mono", "SF Mono", "Menlo"]
        case .medium:
            return ["JetBrainsMonoRoman-Medium", "JetBrainsMono-Regular", "JetBrains Mono", "SF Mono", "Menlo"]
        default:
            return ["JetBrainsMono-Regular", "JetBrains Mono", "SF Mono", "Menlo"]
        }
    }
}

struct ClickyAuraBackground: View {
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.background, theme.muted],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [theme.primary.opacity(0.12), .clear, theme.glowA.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)

            Circle()
                .fill(theme.glowA.opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: -260, y: -250)

            Circle()
                .fill(theme.glowB.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 120)
                .offset(x: 280, y: -220)
        }
        .ignoresSafeArea()
    }
}

struct ClickyGlassCardSurface: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 0.9)
            )
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(theme.primary.opacity(0.08)), in: shape)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.fill(theme.card.opacity(0.16)))
        }
    }
}

extension View {
    func clickyGlassCard(cornerRadius: CGFloat = 26, padding: CGFloat = 20) -> some View {
        modifier(ClickyGlassCardSurface(cornerRadius: cornerRadius, padding: padding))
    }
}

struct ClickyFrameSurface: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.background.opacity(0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
    }
}

extension View {
    func clickyFrameSurface(cornerRadius: CGFloat = 28, padding: CGFloat = 20) -> some View {
        modifier(ClickyFrameSurface(cornerRadius: cornerRadius, padding: padding))
    }
}

struct ClickyGlassCluster<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                content
            }
        } else {
            content
        }
    }
}
