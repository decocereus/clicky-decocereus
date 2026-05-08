//
//  CompanionStudioChrome.swift
//  leanring-buddy
//
//  Shared shell chrome for the Studio window.
//

import AppKit
import SwiftUI

struct CompanionStudioWindowHeader: View {
    let theme: ClickyTheme
    let palette: CompanionStudioScalaPalette
    let sections: [CompanionStudioNextSection]
    @Binding var selection: CompanionStudioNextSection
    var showsSectionTabs: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("clicky")
                    .font(ClickyTypography.brand(size: 34))
                    .foregroundColor(palette.brandWordmark)

                Text("Studio")
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.shellSecondaryText)
                    .tracking(1.0)
            }

            Spacer(minLength: 0)

            if showsSectionTabs {
                topTabs
            }
        }
    }

    @ViewBuilder
    private var topTabs: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    tabButtons
                }
            } else {
                tabButtons
            }
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 14) {
            ForEach(sections) { section in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selection = section
                    }
                } label: {
                    Image(systemName: section.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .help(section.title)
                .accessibilityLabel(section.title)
                .modifier(CompanionStudioToolbarIconButtonModifier(isSelected: selection == section))
            }
        }
    }
}

struct CompanionStudioSceneShell<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }
}

struct CompanionStudioReadableCard<Content: View>: View {
    let palette = CompanionStudioScalaPalette()

    let eyebrow: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardSecondaryText)
                    .tracking(1.0)

                Text(title)
                    .font(ClickyTypography.section(size: 30))
                    .foregroundColor(palette.cardPrimaryText)
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.cardBackground)
                .overlay(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            palette.cardAccent.opacity(0.12),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.72), lineWidth: 0.9)
                )
        )
    }
}

struct CompanionStudioKeyValueRow: View {
    let label: String
    let value: String
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .frame(width: 96, alignment: .leading)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
    }
}

struct CompanionStudioAccessAvatar: View {
    let initials: String
    let imageURL: String
    let palette: CompanionStudioScalaPalette

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.sage.opacity(0.92),
                            palette.cardAccent.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let avatarURL = resolvedAvatarURL {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    fallbackInitials
                }
                .clipShape(Circle())
            } else {
                fallbackInitials
            }

            Circle()
                .stroke(palette.cardBorder.opacity(0.55), lineWidth: 1)
        }
        .frame(width: 56, height: 56)
    }

    private var resolvedAvatarURL: URL? {
        let trimmedURL = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            return nil
        }

        return URL(string: trimmedURL)
    }

    private var fallbackInitials: some View {
        Text(initials.isEmpty ? "CU" : initials)
            .font(ClickyTypography.mono(size: 18, weight: .semibold))
            .foregroundColor(palette.cardPrimaryText)
    }
}

struct CompanionStudioAccessCelebrationCard: View {
    @State private var isAnimating = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.sage.opacity(0.88),
                                palette.cardAccent.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.50), lineWidth: 1)
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(palette.cardPrimaryText)
                    .scaleEffect(isAnimating ? 1.03 : 0.98)
            }
            .frame(width: 60, height: 60)
            .shadow(color: palette.sage.opacity(isAnimating ? 0.18 : 0.08), radius: isAnimating ? 14 : 8, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("Subscription active")
                    .font(ClickyTypography.section(size: 22))
                    .foregroundColor(palette.cardPrimaryText)

                Text("You’ve bought full access, so Clicky is now yours to use however much you want.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardAccent.opacity(0.36))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.42), lineWidth: 0.9)
                )
        )
        .onAppear {
            guard !isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct CompanionStudioGlassChip: View {
    let text: String
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        let shape = Capsule(style: .continuous)

        Group {
            if #available(macOS 26.0, *) {
                Text(text)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .glassEffect(.regular, in: shape)
            } else {
                Text(text)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(shape.fill(.ultraThinMaterial))
            }
        }
        .fixedSize()
    }
}

struct CompanionStudioHairline: View {
    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.clear,
                        palette.cardBorder.opacity(0.65),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

struct CompanionStudioPrimaryButtonModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.primary.opacity(0.10))
                )
        }
    }
}

struct CompanionStudioSecondaryButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.cardAccent.opacity(0.45))
                )
        }
    }
}

struct CompanionStudioModeButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            } else {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            }
        } else {
            content
                .foregroundColor(isSelected ? .white : palette.cardPrimaryText)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? palette.sage : palette.cardAccent.opacity(0.50))
                )
        }
    }
}

struct CompanionStudioNextBackdrop: View {
    let theme: ClickyTheme
    let palette: CompanionStudioScalaPalette

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
            } else {
                LinearGradient(
                    colors: [
                        palette.shellBackgroundTop.opacity(0.92),
                        palette.shellBackgroundMid.opacity(0.90),
                        palette.shellBackgroundBottom.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct CompanionStudioJourneyStep: View {
    let step: String
    let title: String
    let copy: String

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(step)
                    .font(ClickyTypography.mono(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(palette.cardPrimaryText)
                    )

                Text(title)
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)
            }

            Text(copy)
                .font(ClickyTypography.body(size: 13))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardAccent.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.48), lineWidth: 0.8)
                )
        )
    }
}

struct CompanionStudioPreferenceRow: View {
    let title: String
    let subtitle: String
    let control: AnyView

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.body(size: 14, weight: .semibold))
                    .foregroundColor(palette.cardPrimaryText)

                Text(subtitle)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(palette.cardSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            control
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

struct CompanionStudioPreferenceBlock: View {
    let title: String
    let subtitle: String
    let content: AnyView

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)

            Text(subtitle)
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(palette.cardSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

struct CompanionStudioMiniMetric: View {
    let title: String
    let value: String
    var allowExpansion: Bool = false

    private let palette = CompanionStudioScalaPalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(palette.cardSecondaryText)
                .tracking(0.8)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .semibold))
                .foregroundColor(palette.cardPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: allowExpansion ? .infinity : nil, alignment: .leading)
        .frame(minWidth: 0, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardAccent.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardBorder.opacity(0.40), lineWidth: 0.8)
                )
        )
    }
}

struct CompanionStudioSelectableRowButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            } else {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
            }
        } else {
            content
                .foregroundColor(palette.cardPrimaryText)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? palette.sage.opacity(0.18) : Color.white.opacity(0.52))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? palette.sage.opacity(0.45) : palette.cardBorder.opacity(0.28),
                                    lineWidth: 0.9
                                )
                        )
                )
        }
    }
}

struct CompanionStudioToolbarIconButtonModifier: ViewModifier {
    private let palette = CompanionStudioScalaPalette()
    let isSelected: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        if #available(macOS 26.0, *) {
            if isSelected {
                content
                    .foregroundColor(palette.cardPrimaryText)
                    .background(
                        shape
                            .fill(palette.cardBackground.opacity(0.94))
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.30), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
            } else {
                content
                    .foregroundColor(Color.white.opacity(0.88))
                    .background(
                        shape
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        shape
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    )
            }
        } else {
            content
                .foregroundColor(isSelected ? palette.cardPrimaryText : Color.white.opacity(0.88))
                .background(
                    shape
                        .fill(isSelected ? palette.cardBackground.opacity(0.94) : Color.white.opacity(0.05))
                )
                .overlay(
                    shape
                        .stroke(isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 0.6)
                )
        }
    }
}

struct CompanionStudioScalaPalette {
    let shellBackgroundTop = Color(hex: "#F2FCFF")
    let shellBackgroundMid = Color(hex: "#EAF8FF")
    let shellBackgroundBottom = Color(hex: "#DDE8EE")

    let shellTint = Color(hex: "#4FE7EE")
    let shellPrimaryText = Color(hex: "#16212B")
    let shellSecondaryText = Color(hex: "#5D7283")

    let cardBackground = Color(hex: "#FAFCFF")
    let cardPrimaryText = Color(hex: "#16212B")
    let cardSecondaryText = Color(hex: "#5D7283")
    let cardBorder = Color(hex: "#DDE8EE")
    let cardAccent = Color(hex: "#EAF8FF")

    let lavender = Color(hex: "#8EA2FF")
    let sage = Color(hex: "#4FE7EE")
    let sageText = Color(hex: "#3478F6")
    let brandWordmark = Color(hex: "#16212B")
}

struct CompanionStudioNextWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        DispatchQueue.main.async {
            guard let window = view.window else { return }

            positionTrafficLights(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }

            positionTrafficLights(for: window)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.toolbar = nil
            window.styleMask.insert(.fullSizeContentView)
            if #available(macOS 11.0, *) {
                window.titlebarSeparatorStyle = .none
            }
        }
    }

    private func positionTrafficLights(for window: NSWindow) {
        guard
            let closeButton = window.standardWindowButton(.closeButton),
            let miniButton = window.standardWindowButton(.miniaturizeButton),
            let zoomButton = window.standardWindowButton(.zoomButton)
        else {
            return
        }

        let targetY: CGFloat = 14
        let startX: CGFloat = 14
        let spacing: CGFloat = 6

        closeButton.setFrameOrigin(NSPoint(x: startX, y: targetY))
        miniButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + spacing, y: targetY))
        zoomButton.setFrameOrigin(NSPoint(x: startX + closeButton.frame.width + miniButton.frame.width + (spacing * 2), y: targetY))
    }
}

struct CompanionStudioNextWindowBackgroundClearStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(Color.clear, for: .window)
        } else {
            content
        }
    }
}
