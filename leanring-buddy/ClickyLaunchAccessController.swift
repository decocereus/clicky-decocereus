//
//  ClickyLaunchAccessController.swift
//  leanring-buddy
//
//  Observable launch-auth, entitlement, and billing state for Clicky.
//

import Combine
import Foundation

@MainActor
final class ClickyLaunchAccessController: ObservableObject {
    @Published var clickyLaunchAuthState: ClickyLaunchAuthState = .signedOut
    @Published var clickyLaunchEntitlementStatusLabel: String = "Unknown"
    @Published var clickyLaunchBillingState: ClickyLaunchBillingState = .idle
    @Published var clickyLaunchTrialState: ClickyLaunchTrialState = .inactive
    @Published var clickyLaunchProfileName: String = ""
    @Published var clickyLaunchProfileImageURL: String = ""
}
