//
//  CompanionStudioAccessChrome.swift
//  leanring-buddy
//
//  Shared access/account visuals for Studio scenes.
//

import SwiftUI

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
