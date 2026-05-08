//
//  CompanionStudioButtonModifiers.swift
//  leanring-buddy
//
//  Shared Studio button treatments.
//

import SwiftUI

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
