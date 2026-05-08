//
//  CompanionStudioChrome.swift
//  leanring-buddy
//
//  Shared shell chrome for the Studio window.
//

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
