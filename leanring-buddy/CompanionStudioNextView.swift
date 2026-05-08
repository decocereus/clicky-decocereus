//
//  CompanionStudioNextView.swift
//  leanring-buddy
//
//  Parallel replacement Studio root with top tabs and scene-by-scene rebuilds.
//

import SwiftUI

enum CompanionStudioNextSection: String, CaseIterable, Identifiable, Hashable {
    case companion
    case profile
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .companion:
            return "Companion"
        case .profile:
            return "Profile"
        case .support:
            return "Support"
        }
    }

    var subtitle: String {
        switch self {
        case .companion:
            return "Daily shell controls"
        case .profile:
            return "Account, access, and app"
        case .support:
            return "Diagnostics and backstage tools"
        }
    }

    var systemImage: String {
        switch self {
        case .companion:
            return "sparkles"
        case .profile:
            return "person.crop.circle"
        case .support:
            return "stethoscope"
        }
    }
}

struct CompanionStudioNextView: View {
    let companionManager: CompanionManager
    @ObservedObject private var preferences: ClickyPreferencesStore
    @ObservedObject private var launchAccessController: ClickyLaunchAccessController
    @ObservedObject private var surfaceController: ClickySurfaceController

    @AppStorage("clickySupportModeEnabled") private var isSupportModeEnabled = false
    @State private var selection: CompanionStudioNextSection = .companion

    private let palette = CompanionStudioScalaPalette()

    init(companionManager: CompanionManager) {
        self.companionManager = companionManager
        _preferences = ObservedObject(wrappedValue: companionManager.preferences)
        _launchAccessController = ObservedObject(wrappedValue: companionManager.launchAccessController)
        _surfaceController = ObservedObject(wrappedValue: companionManager.surfaceController)
    }

    private var launchAccess: CompanionStudioLaunchAccessSnapshot {
        CompanionStudioLaunchAccessSnapshot(
            authState: launchAccessController.clickyLaunchAuthState,
            billingState: launchAccessController.clickyLaunchBillingState,
            trialState: launchAccessController.clickyLaunchTrialState,
            profileName: launchAccessController.clickyLaunchProfileName,
            profileImageURL: launchAccessController.clickyLaunchProfileImageURL,
            hasCompletedOnboarding: preferences.hasCompletedOnboarding,
            hasAccessibilityPermission: surfaceController.hasAccessibilityPermission,
            hasScreenRecordingPermission: surfaceController.hasScreenRecordingPermission,
            hasMicrophonePermission: surfaceController.hasMicrophonePermission,
            hasScreenContentPermission: surfaceController.hasScreenContentPermission
        )
    }

    private var isClickyLaunchAuthPending: Bool {
        switch launchAccessController.clickyLaunchAuthState {
        case .restoring, .signingIn:
            return true
        case .signedOut, .signedIn, .failed:
            return false
        }
    }

    private var availableSections: [CompanionStudioNextSection] {
        CompanionStudioNextSection.allCases.filter { section in
            if section == .support {
                return isSupportModeEnabled
            }
            return true
        }
    }

    private var isLaunchAuthGateActive: Bool {
        launchAccess.requiresSignInForCompanionUse || isClickyLaunchAuthPending
    }

    var body: some View {
        ZStack {
            CompanionStudioNextBackdrop(palette: palette)

            VStack(alignment: .leading, spacing: 18) {
                CompanionStudioWindowHeader(
                    palette: palette,
                    sections: availableSections,
                    selection: $selection,
                    showsSectionTabs: !isLaunchAuthGateActive
                )

                CompanionStudioSceneShell {
                    currentScene
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 12)
            .background(outerShell)
        }
        .modifier(CompanionStudioNextWindowBackgroundClearStyle())
        .background(CompanionStudioNextWindowConfigurator())
        .onChange(of: isSupportModeEnabled) { _, newValue in
            if !newValue && selection == .support {
                selection = .companion
            }
        }
    }

    @ViewBuilder
    private var currentScene: some View {
        if isLaunchAuthGateActive {
            CompanionStudioLaunchAuthScene(companionManager: companionManager)
        } else {
            switch selection {
            case .companion:
                CompanionStudioCompanionScene(
                    companionManager: companionManager,
                    isSupportModeEnabled: $isSupportModeEnabled
                )
            case .profile:
                CompanionStudioProfileScene(companionManager: companionManager)
            case .support:
                CompanionStudioSupportScene(
                    companionManager: companionManager,
                    isSupportModeEnabled: $isSupportModeEnabled
                )
            }
        }
    }

    @ViewBuilder
    private var outerShell: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        if #available(macOS 26.0, *) {
            Color.clear
                .padding(12)
                .glassEffect(.clear, in: shape)
                .overlay(
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.10),
                                    palette.sage.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.10), radius: 18, y: 8)
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay(
                    shape.fill(Color.white.opacity(0.06))
                )
                .overlay(
                    shape.stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
        }
    }
}
