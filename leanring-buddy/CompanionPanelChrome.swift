//
//  CompanionPanelChrome.swift
//  leanring-buddy
//
//  Shared menu-bar panel screen models, styling, and lightweight chrome.
//

import SwiftUI

enum CompanionPanelScreen {
    case welcome
    case signIn
    case permissions
    case ready
    case active
    case locked
    case repair
    case tutorialEntry
    case tutorialImportEntry
    case tutorialImportMissingSetup
    case tutorialExtracting
    case tutorialCompiling
    case tutorialReady
    case tutorialPlayback
    case tutorialFailed
}

enum CompanionPanelOnboardingStage: Int {
    case welcome
    case signIn
    case permissions
    case ready
}

enum CompanionPermissionKind: Hashable {
    case accessibility
    case microphone
    case screenRecording
    case screenContent
}

enum CompanionPermissionRowState: Equatable {
    case missing
    case granted

    func dotColor(_ theme: ClickyTheme) -> Color {
        switch self {
        case .missing:
            return theme.warning.opacity(0.7)
        case .granted:
            return theme.success.opacity(0.75)
        }
    }

    func backgroundColor(_ theme: ClickyTheme) -> Color {
        switch self {
        case .missing:
            return Color.clear
        case .granted:
            return theme.success.opacity(0.08)
        }
    }

    func borderColor(_ theme: ClickyTheme) -> Color {
        switch self {
        case .missing:
            return Color.clear
        case .granted:
            return theme.success.opacity(0.22)
        }
    }
}

struct CompanionPanelPermissionRow: Identifiable {
    let id = UUID()
    let kind: CompanionPermissionKind
    let title: String
    let detail: String
    let primaryTitle: String
    let primaryAction: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var state: CompanionPermissionRowState = .missing

    func withState(_ state: CompanionPermissionRowState) -> Self {
        var copy = self
        copy.state = state
        return copy
    }
}

enum PanelInlineStatusTone {
    case neutral
    case success
    case warning
    case info
}

enum ClickyPanelContentTone {
    case regular
    case hero
    case subtle
}

struct ClickyPanelContentCardStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    let tone: ClickyPanelContentTone
    let padding: CGFloat

    init(tone: ClickyPanelContentTone = .regular, padding: CGFloat = 15) {
        self.tone = tone
        self.padding = padding
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

        content
            .clickyTheme(theme.contentSurfaceTheme)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                shape
                    .fill(backgroundFill)
                    .overlay(shape.fill(highlightFill))
            )
            .overlay(
                shape
                    .stroke(borderColor, lineWidth: 0.9)
            )
            .shadow(color: Color.black.opacity(tone == .subtle ? 0.04 : 0.07), radius: 18, y: 8)
    }

    private var backgroundFill: Color {
        switch tone {
        case .regular:
            return theme.card.opacity(0.92)
        case .hero:
            return theme.secondary.opacity(0.96)
        case .subtle:
            return theme.card.opacity(0.82)
        }
    }

    private var highlightFill: LinearGradient {
        switch tone {
        case .regular:
            return LinearGradient(
                colors: [Color.white.opacity(0.08), theme.secondary.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hero:
            return LinearGradient(
                colors: [Color.white.opacity(0.10), theme.primary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .subtle:
            return LinearGradient(
                colors: [Color.white.opacity(0.06), theme.secondary.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        switch tone {
        case .regular:
            return theme.border.opacity(0.72)
        case .hero:
            return theme.primary.opacity(0.22)
        case .subtle:
            return theme.border.opacity(0.52)
        }
    }
}

struct ClickyProminentActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme
    let attentionMode: ClickyPanelAttentionMode

    init(attentionMode: ClickyPanelAttentionMode = .none) {
        self.attentionMode = attentionMode
    }

    func body(content: Content) -> some View {
        content
            .buttonStyle(ClickyPrimaryPanelButtonStyle(theme: theme, attentionMode: attentionMode))
    }
}

struct ClickySecondaryGlassButtonStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        content
            .buttonStyle(ClickySecondaryPanelButtonStyle(theme: theme))
    }
}

enum ClickyPanelAttentionMode {
    case none
    case singlePulse
    case loopingPulse
}

struct ClickyPrimaryPanelButtonStyle: ButtonStyle {
    let theme: ClickyTheme
    let attentionMode: ClickyPanelAttentionMode

    @State private var isHovered = false
    @State private var pulseAmount: CGFloat = 0
    @State private var triggeredSinglePulse = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ClickyTypography.body(size: 13, weight: .semibold))
            .foregroundColor(theme.accentForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.primary)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.22 : 0.10),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.18 : 0.10), lineWidth: 0.9)
            )
            .shadow(
                color: theme.accent.opacity(attentionShadowOpacity),
                radius: 10 + (pulseAmount * 8),
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.985 : (isHovered ? 1.01 : (1 + (pulseAmount * 0.015))))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .onAppear {
                startPulseIfNeeded()
            }
    }

    private var attentionShadowOpacity: Double {
        switch attentionMode {
        case .none:
            return isHovered ? 0.16 : 0.10
        case .singlePulse, .loopingPulse:
            return 0.16 + (0.18 * Double(pulseAmount))
        }
    }

    private func startPulseIfNeeded() {
        switch attentionMode {
        case .none:
            pulseAmount = 0
        case .singlePulse:
            guard !triggeredSinglePulse else { return }
            triggeredSinglePulse = true
            pulseAmount = 0
            withAnimation(.easeInOut(duration: 1.2)) {
                pulseAmount = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.4)) {
                    pulseAmount = 0
                }
            }
        case .loopingPulse:
            pulseAmount = 0
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulseAmount = 1
            }
        }
    }
}

struct ClickySecondaryPanelButtonStyle: ButtonStyle {
    let theme: ClickyTheme

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let contentTheme = theme.contentSurfaceTheme

        return configuration.label
            .font(ClickyTypography.body(size: 12, weight: .semibold))
            .foregroundColor(contentTheme.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .multilineTextAlignment(.center)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(contentTheme.card.opacity(isHovered ? 1.0 : 0.98))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(contentTheme.border.opacity(isHovered ? 0.98 : 0.86), lineWidth: 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : (isHovered ? 1.003 : 1.0))
            .shadow(color: Color.black.opacity(isHovered ? 0.10 : 0.07), radius: 8, y: 3)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct ClickyFooterActionStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.background.opacity(0.42))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
    }
}

struct ClickyTinyGlassCircleStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(buttonFill)
                    .overlay(
                        Circle()
                            .stroke(buttonStroke, lineWidth: 1)
                    )
                    .overlay(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.34 : 0.22),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(1)
                            .clipShape(Circle())
                    )
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.10 : 0.06), radius: 8, y: 3)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var buttonFill: Color {
        let base = theme.contentSurfaceTheme.card
        return base.opacity(isHovered ? 0.94 : 0.88)
    }

    private var buttonStroke: Color {
        theme.contentSurfaceTheme.border.opacity(isHovered ? 0.95 : 0.82)
    }
}

struct ClickyPanelShellStyle: ViewModifier {
    @Environment(\.clickyTheme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

        if #available(macOS 26.0, *) {
            content
                .padding(18)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.10),
                                    theme.primary.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 28, y: 16)
        } else {
            content
                .clickyGlassCard(cornerRadius: 28, padding: 18)
        }
    }
}

extension View {
    @ViewBuilder
    func panelGlassMotionID(_ identifier: String, namespace: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffectID(identifier, in: namespace)
        } else {
            self
        }
    }
}

struct PanelCardTransitionModifier: ViewModifier {
    let opacity: Double
    let offsetY: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: offsetY)
    }
}

struct CompanionCreditsChip: View {
    let label: String
    let tone: PanelInlineStatusTone

    @State private var shimmerOffset: CGFloat = -1
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        Text(label)
            .font(ClickyTypography.mono(size: 10, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
                    .overlay {
                        GeometryReader { geometry in
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: geometry.size.width * 0.4)
                            .offset(x: geometry.size.width * shimmerOffset)
                            .blendMode(.screen)
                        }
                        .clipShape(Capsule(style: .continuous))
                    }
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            )
            .onAppear {
                shimmerOffset = -1
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false).delay(2.8)) {
                    shimmerOffset = 1.6
                }
            }
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return theme.textSecondary
        case .success:
            return theme.success
        case .warning:
            return theme.warning
        case .info:
            return theme.accentStrong
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .neutral:
            return Color.white.opacity(0.02)
        case .success:
            return theme.success.opacity(0.12)
        case .warning:
            return theme.warning.opacity(0.12)
        case .info:
            return theme.primary.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .neutral:
            return theme.strokeSoft
        case .success:
            return theme.success.opacity(0.3)
        case .warning:
            return theme.warning.opacity(0.3)
        case .info:
            return theme.primary.opacity(0.3)
        }
    }
}
