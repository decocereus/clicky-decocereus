//
//  CompanionPanelPermissionRows.swift
//  leanring-buddy
//
//  Permission row construction for the menu-bar companion panel.
//

struct CompanionPanelPermissionRowSnapshot {
    let hasCompletedOnboarding: Bool
    let hasAccessibilityPermission: Bool
    let hasMicrophonePermission: Bool
    let hasScreenRecordingPermission: Bool
    let hasScreenContentPermission: Bool
    let isRequestingScreenContent: Bool
    let recentlyGrantedPermissions: Set<CompanionPermissionKind>
}

struct CompanionPanelPermissionRowActions {
    let requestAccessibilityPermission: () -> Void
    let revealAppAndOpenAccessibilitySettings: () -> Void
    let requestMicrophonePermission: () -> Void
    let requestScreenRecordingPermission: () -> Void
    let requestScreenContentPermission: () -> Void
    let continueFromPermissions: () -> Void
}

enum CompanionPanelPermissionRows {
    static func makeRows(
        snapshot: CompanionPanelPermissionRowSnapshot,
        actions: CompanionPanelPermissionRowActions
    ) -> [CompanionPanelPermissionRow] {
        var rows: [CompanionPanelPermissionRow] = []

        if !snapshot.hasAccessibilityPermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .accessibility,
                    title: "Accessibility",
                    detail: snapshot.hasCompletedOnboarding
                        ? "So Clicky can continue helping you act inside software."
                        : "So Clicky can guide and act inside software when you ask.",
                    primaryTitle: "Grant",
                    primaryAction: actions.requestAccessibilityPermission,
                    secondaryTitle: "Find App",
                    secondaryAction: actions.revealAppAndOpenAccessibilitySettings
                ).withState(rowState(for: .accessibility, snapshot: snapshot, isGranted: false))
            )
        } else if snapshot.recentlyGrantedPermissions.contains(.accessibility) {
            rows.append(grantedRow(kind: .accessibility, title: "Accessibility"))
        }

        if !snapshot.hasMicrophonePermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .microphone,
                    title: "Microphone",
                    detail: "So Clicky can listen when you use push-to-talk.",
                    primaryTitle: "Grant",
                    primaryAction: actions.requestMicrophonePermission
                ).withState(rowState(for: .microphone, snapshot: snapshot, isGranted: false))
            )
        } else if snapshot.recentlyGrantedPermissions.contains(.microphone) {
            rows.append(grantedRow(kind: .microphone, title: "Microphone"))
        }

        if !snapshot.hasScreenRecordingPermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .screenRecording,
                    title: "Screen Recording",
                    detail: snapshot.hasCompletedOnboarding
                        ? "So Clicky can continue seeing enough context to guide and act safely."
                        : "So Clicky can see enough context to guide and act safely.",
                    primaryTitle: "Grant",
                    primaryAction: actions.requestScreenRecordingPermission
                ).withState(rowState(for: .screenRecording, snapshot: snapshot, isGranted: false))
            )
        } else if snapshot.recentlyGrantedPermissions.contains(.screenRecording) {
            rows.append(grantedRow(kind: .screenRecording, title: "Screen Recording"))
        }

        if snapshot.hasScreenRecordingPermission && !snapshot.hasScreenContentPermission {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .screenContent,
                    title: "Screen Content",
                    detail: "So Clicky can still understand the text and interfaces in front of you.",
                    primaryTitle: snapshot.isRequestingScreenContent ? "Waiting…" : "Grant",
                    primaryAction: actions.requestScreenContentPermission
                ).withState(rowState(for: .screenContent, snapshot: snapshot, isGranted: false))
            )
        } else if snapshot.hasScreenRecordingPermission && snapshot.recentlyGrantedPermissions.contains(.screenContent) {
            rows.append(grantedRow(kind: .screenContent, title: "Screen Content"))
        }

        if rows.isEmpty {
            rows.append(
                CompanionPanelPermissionRow(
                    kind: .accessibility,
                    title: "All set",
                    detail: "Everything Clicky needs is already available.",
                    primaryTitle: "Continue",
                    primaryAction: actions.continueFromPermissions
                ).withState(.granted)
            )
        }

        return rows
    }

    private static func rowState(
        for kind: CompanionPermissionKind,
        snapshot: CompanionPanelPermissionRowSnapshot,
        isGranted: Bool
    ) -> CompanionPermissionRowState {
        if isGranted || snapshot.recentlyGrantedPermissions.contains(kind) {
            return .granted
        }

        return .missing
    }

    private static func grantedRow(
        kind: CompanionPermissionKind,
        title: String
    ) -> CompanionPanelPermissionRow {
        CompanionPanelPermissionRow(
            kind: kind,
            title: title,
            detail: "Resolved and quiet again.",
            primaryTitle: "Grant",
            primaryAction: {}
        ).withState(.granted)
    }
}
