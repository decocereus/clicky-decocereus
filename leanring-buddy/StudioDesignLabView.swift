//
//  StudioDesignLabView.swift
//  leanring-buddy
//
//  Three Studio redesign directions for side-by-side product review.
//

import SwiftUI

private enum StudioDesignConcept: String, CaseIterable, Identifiable {
    case editorialSidebar
    case floatingChapters
    case commandDeck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editorialSidebar:
            return "Editorial Sidebar"
        case .floatingChapters:
            return "Floating Chapters"
        case .commandDeck:
            return "Command Deck"
        }
    }

    var summary: String {
        switch self {
        case .editorialSidebar:
            return "Warm, serif-led and familiar. Best for a production-ready settings surface."
        case .floatingChapters:
            return "Story-driven and expressive. Closest to the current web app’s chapter rhythm."
        case .commandDeck:
            return "Operational and premium. Best for dense status, controls, and future expansion."
        }
    }

    var accent: Color {
        switch self {
        case .editorialSidebar:
            return Color(hex: "#9B8FBF")
        case .floatingChapters:
            return Color(hex: "#7A9B8A")
        case .commandDeck:
            return Color(hex: "#C78BA0")
        }
    }

    var systemImage: String {
        switch self {
        case .editorialSidebar:
            return "books.vertical"
        case .floatingChapters:
            return "rectangle.stack"
        case .commandDeck:
            return "dial.medium"
        }
    }
}

struct StudioDesignLabView: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.clickyTheme) private var theme
    @Namespace private var glassNamespace

    @State private var selectedConcept: StudioDesignConcept = .editorialSidebar

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            conceptPicker
            conceptSummary
            conceptPreview
        }
    }

    private var conceptPicker: some View {
        HStack(spacing: 12) {
            ForEach(StudioDesignConcept.allCases) { concept in
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        selectedConcept = concept
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: concept.systemImage)
                            .font(.system(size: 12, weight: .semibold))

                        Text(concept.title)
                            .font(ClickyTypography.body(size: 13, weight: .semibold))
                    }
                    .foregroundColor(selectedConcept == concept ? .white : theme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(conceptChipBackground(for: concept))
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
    }

    @ViewBuilder
    private func conceptChipBackground(for concept: StudioDesignConcept) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        if selectedConcept == concept {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular.tint(concept.accent.opacity(0.75)).interactive(), in: shape)
                    .glassEffectID("chip-\(concept.rawValue)", in: glassNamespace)
            } else {
                shape.fill(concept.accent)
            }
        } else {
            shape
                .fill(theme.card.opacity(0.6))
                .overlay(shape.stroke(theme.strokeSoft, lineWidth: 1))
        }
    }

    private var conceptSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedConcept.title)
                .font(ClickyTypography.section(size: 30))
                .foregroundColor(theme.textPrimary)

            Text(selectedConcept.summary)
                .font(ClickyTypography.body(size: 14))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(theme.card.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(theme.strokeSoft, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var conceptPreview: some View {
        switch selectedConcept {
        case .editorialSidebar:
            EditorialSidebarStudioConcept(companionManager: companionManager)
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
        case .floatingChapters:
            FloatingChaptersStudioConcept(companionManager: companionManager)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
        case .commandDeck:
            CommandDeckStudioConcept(companionManager: companionManager)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
        }
    }
}

private struct EditorialSidebarStudioConcept: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                designSidebarPill(title: "Companion", subtitle: "Daily setup", isSelected: true)
                designSidebarPill(title: "Voice & Persona", subtitle: "Tone and cursor", isSelected: false)
                designSidebarPill(title: "Connection", subtitle: "OpenClaw and auth", isSelected: false)
                designSidebarPill(title: "Launch Access", subtitle: "Buy and restore", isSelected: false)
                designSidebarPill(title: "Support", subtitle: "Debug only", isSelected: false)
                Spacer()
            }
            .frame(width: 220)

            VStack(alignment: .leading, spacing: 16) {
                DesignGlassCard(title: "Companion", subtitle: "Production-facing essentials only") {
                    VStack(alignment: .leading, spacing: 12) {
                        DesignMetricRow(label: "Backend", value: companionManager.clickyBackendStatusLabel)
                        DesignMetricRow(label: "Speech", value: companionManager.effectiveVoiceOutputDisplayName)
                        DesignMetricRow(label: "Mode", value: companionManager.selectedAgentBackend.displayName)
                    }
                }

                DesignGlassCard(title: "Launch Access", subtitle: "Clean actions, no test controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        DesignMetricRow(label: "Account", value: companionManager.clickyLaunchAuthStatusLabel)
                        DesignMetricRow(label: "Entitlement", value: companionManager.clickyLaunchEntitlementStatusLabel)
                        DesignMetricRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                        HStack(spacing: 10) {
                            DesignPrimaryMockButton(title: "Buy Launch Pass", accent: Color(hex: "#9B8FBF"))
                            DesignSecondaryMockButton(title: "Restore Access")
                        }
                    }
                }

                DesignGlassCard(title: "Support", subtitle: "Diagnostics lives in its own quieter surface") {
                    Text("Trial manipulation, raw shell state, and support exports all live here instead of leaking into the user-facing Studio.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .background(DesignPreviewChrome(accent: Color(hex: "#9B8FBF")))
    }

    private func designSidebarPill(title: String, subtitle: String, isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ClickyTypography.body(size: 13, weight: .semibold))
            Text(subtitle)
                .font(ClickyTypography.mono(size: 10, weight: .medium))
                .foregroundColor(theme.textMuted)
        }
        .foregroundColor(isSelected ? .white : theme.textPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if isSelected {
                    shape.fill(Color(hex: "#9B8FBF"))
                } else {
                    shape.fill(theme.card.opacity(0.6))
                }
            }
        )
        .overlay(shape.stroke(theme.strokeSoft, lineWidth: isSelected ? 0 : 1))
    }
}

private struct FloatingChaptersStudioConcept: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DesignChapterCard(
                eyebrow: "Chapter 01",
                title: "What Clicky is",
                subtitle: "A warmer, story-led Studio that feels like part product walkthrough, part control surface.",
                accent: Color(hex: "#7A9B8A")
            ) {
                HStack(spacing: 12) {
                    DesignMetricBadge(title: "Account", value: companionManager.clickyLaunchAuthStatusLabel)
                    DesignMetricBadge(title: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                    DesignMetricBadge(title: "Entitlement", value: companionManager.clickyLaunchEntitlementStatusLabel)
                }
            }

            DesignChapterCard(
                eyebrow: "Chapter 02",
                title: "How you unlock it",
                subtitle: "Purchase and restore stay visible, but diagnostics never pollute this chapter.",
                accent: Color(hex: "#B5906D")
            ) {
                HStack(spacing: 10) {
                    DesignPrimaryMockButton(title: "Buy Launch Pass", accent: Color(hex: "#7A9B8A"))
                    DesignSecondaryMockButton(title: "Restore Access")
                }
            }

            DesignChapterCard(
                eyebrow: "Support",
                title: "Diagnostics lives elsewhere",
                subtitle: "A dedicated technical chapter holds credit tools, exports, and shell-level debugging so the main Studio stays clean.",
                accent: Color(hex: "#C78BA0")
            ) {
                Text("This direction is the closest to the current website’s rhythm: big editorial sections, slower reveals, and more theatrical breathing room.")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(22)
        .background(DesignPreviewChrome(accent: Color(hex: "#7A9B8A")))
    }
}

private struct CommandDeckStudioConcept: View {
    @ObservedObject var companionManager: CompanionManager
    @Environment(\.clickyTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                DesignGlassCard(title: "Companion", subtitle: "Fast operational summary") {
                    VStack(alignment: .leading, spacing: 10) {
                        DesignMetricRow(label: "Backend", value: companionManager.clickyBackendStatusLabel)
                        DesignMetricRow(label: "Overlay", value: companionManager.isOverlayVisible ? "Visible" : "Hidden")
                        DesignMetricRow(label: "Voice", value: companionManager.effectiveVoiceOutputDisplayName)
                    }
                }

                DesignGlassCard(title: "Launch Access", subtitle: "Account, trial, unlock") {
                    VStack(alignment: .leading, spacing: 10) {
                        DesignMetricRow(label: "Account", value: companionManager.clickyLaunchAuthStatusLabel)
                        DesignMetricRow(label: "Trial", value: companionManager.clickyLaunchTrialStatusLabel)
                        DesignMetricRow(label: "Entitlement", value: companionManager.clickyLaunchEntitlementStatusLabel)
                        DesignMetricRow(label: "Checkout", value: companionManager.clickyLaunchBillingStatusLabel)
                    }
                }
            }

            HStack(alignment: .top, spacing: 18) {
                DesignGlassCard(title: "Primary Actions", subtitle: "Production-facing controls only") {
                    HStack(spacing: 10) {
                        DesignPrimaryMockButton(title: "Buy Launch Pass", accent: Color(hex: "#C78BA0"))
                        DesignSecondaryMockButton(title: "Restore Access")
                    }
                }

                DesignGlassCard(title: "Support Inspector", subtitle: "Slide-out debug surface") {
                    Text("Support mode opens a separate inspector for credits, paywall simulation, exports, and raw shell state.")
                        .font(ClickyTypography.body(size: 13))
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(22)
        .background(DesignPreviewChrome(accent: Color(hex: "#C78BA0")))
    }
}

private struct DesignPreviewChrome: View {
    @Environment(\.clickyTheme) private var theme
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(theme.card.opacity(0.86))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(accent.opacity(0.08))
                    .blur(radius: 30)
            )
    }
}

private struct DesignGlassCard<Content: View>: View {
    @Environment(\.clickyTheme) private var theme
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ClickyTypography.section(size: 24))
                    .foregroundColor(theme.textPrimary)

                Text(subtitle)
                    .font(ClickyTypography.mono(size: 11, weight: .medium))
                    .foregroundColor(theme.textMuted)
            }

            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.card.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.strokeSoft, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DesignMetricRow: View {
    @Environment(\.clickyTheme) private var theme
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label.uppercased())
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(theme.textMuted)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(ClickyTypography.body(size: 14, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
    }
}

private struct DesignMetricBadge: View {
    @Environment(\.clickyTheme) private var theme
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(ClickyTypography.mono(size: 10, weight: .semibold))
                .foregroundColor(theme.textMuted)

            Text(value)
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.card.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.strokeSoft, lineWidth: 1)
        )
    }
}

private struct DesignChapterCard<Content: View>: View {
    @Environment(\.clickyTheme) private var theme
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow.uppercased())
                .font(ClickyTypography.mono(size: 11, weight: .semibold))
                .foregroundColor(accent)

            Text(title)
                .font(ClickyTypography.display(size: 34))
                .foregroundColor(theme.textPrimary)

            Text(subtitle)
                .font(ClickyTypography.body(size: 14))
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(theme.card.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct DesignPrimaryMockButton: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(ClickyTypography.body(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent)
            )
    }
}

private struct DesignSecondaryMockButton: View {
    @Environment(\.clickyTheme) private var theme
    let title: String

    var body: some View {
        Text(title)
            .font(ClickyTypography.body(size: 13, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.card.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.strokeSoft, lineWidth: 1)
            )
    }
}
