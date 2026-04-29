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
                background: Color(hex: "#16212B"),
                foreground: Color(hex: "#FAFCFF"),
                card: Color(hex: "#EAF8FF"),
                cardForeground: Color(hex: "#16212B"),
                popover: Color(hex: "#FAFCFF"),
                popoverForeground: Color(hex: "#16212B"),
                primary: Color(hex: "#3478F6"),
                primaryForeground: Color(hex: "#FAFCFF"),
                secondary: Color(hex: "#DDE8EE"),
                secondaryForeground: Color(hex: "#16212B"),
                muted: Color(hex: "#253442"),
                mutedForeground: Color(hex: "#B9CAD5"),
                accent: Color(hex: "#4FE7EE"),
                accentForeground: Color(hex: "#16212B"),
                destructive: Color(hex: "#E86F8E"),
                destructiveForeground: Color(hex: "#FAFCFF"),
                border: Color(hex: "#40576A"),
                input: Color(hex: "#243240"),
                ring: Color(hex: "#8EA2FF"),
                sidebar: Color(hex: "#16212B"),
                sidebarForeground: Color(hex: "#FAFCFF"),
                sidebarPrimary: Color(hex: "#3478F6"),
                sidebarPrimaryForeground: Color(hex: "#FAFCFF"),
                sidebarAccent: Color(hex: "#EAF8FF"),
                sidebarAccentForeground: Color(hex: "#16212B"),
                sidebarBorder: Color(hex: "#40576A"),
                sidebarRing: Color(hex: "#8EA2FF"),
                radius: 16,
                trackingNormal: -0.01,
                glowA: Color(hex: "#4FE7EE"),
                glowB: Color(hex: "#FFB9CF")
            )
        case .light:
            return ClickyTheme(
                background: Color(hex: "#FAFCFF"),
                foreground: Color(hex: "#16212B"),
                card: Color(hex: "#FFFFFF"),
                cardForeground: Color(hex: "#16212B"),
                popover: Color(hex: "#FFFFFF"),
                popoverForeground: Color(hex: "#16212B"),
                primary: Color(hex: "#3478F6"),
                primaryForeground: Color(hex: "#FAFCFF"),
                secondary: Color(hex: "#EAF8FF"),
                secondaryForeground: Color(hex: "#16212B"),
                muted: Color(hex: "#F2F8FB"),
                mutedForeground: Color(hex: "#5D7283"),
                accent: Color(hex: "#4FE7EE"),
                accentForeground: Color(hex: "#16212B"),
                destructive: Color(hex: "#E86F8E"),
                destructiveForeground: Color(hex: "#FAFCFF"),
                border: Color(hex: "#DDE8EE"),
                input: Color(hex: "#EAF8FF"),
                ring: Color(hex: "#8EA2FF"),
                sidebar: Color(hex: "#F2F8FB"),
                sidebarForeground: Color(hex: "#16212B"),
                sidebarPrimary: Color(hex: "#3478F6"),
                sidebarPrimaryForeground: Color(hex: "#FAFCFF"),
                sidebarAccent: Color(hex: "#EAF8FF"),
                sidebarAccentForeground: Color(hex: "#16212B"),
                sidebarBorder: Color(hex: "#DDE8EE"),
                sidebarRing: Color(hex: "#8EA2FF"),
                radius: 16,
                trackingNormal: -0.01,
                glowA: Color(hex: "#4FE7EE"),
                glowB: Color(hex: "#FFB9CF")
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
    var success: Color { primary }
    var warning: Color { Color(hex: "#FFB224") }
    
    var contentSurfaceTheme: ClickyTheme {
        ClickyTheme(
            background: card,
            foreground: cardForeground,
            card: card,
            cardForeground: cardForeground,
            popover: popover,
            popoverForeground: popoverForeground,
            primary: primary,
            primaryForeground: primaryForeground,
            secondary: secondary,
            secondaryForeground: secondaryForeground,
            muted: muted,
            mutedForeground: mutedForeground,
            accent: accent,
            accentForeground: accentForeground,
            destructive: destructive,
            destructiveForeground: destructiveForeground,
            border: border,
            input: input,
            ring: ring,
            sidebar: sidebar,
            sidebarForeground: sidebarForeground,
            sidebarPrimary: sidebarPrimary,
            sidebarPrimaryForeground: sidebarPrimaryForeground,
            sidebarAccent: sidebarAccent,
            sidebarAccentForeground: sidebarAccentForeground,
            sidebarBorder: sidebarBorder,
            sidebarRing: sidebarRing,
            radius: radius,
            trackingNormal: trackingNormal,
            glowA: glowA,
            glowB: glowB
        )
    }
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
