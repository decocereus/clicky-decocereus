//
//  ClickyLaunchPostTurnRecorder.swift
//  leanring-buddy
//
//  Persists launch trial/paywall bookkeeping after assistant turns.
//

import Foundation

@MainActor
struct ClickyLaunchPostTurnRecorder {
    let sessionService: ClickyLaunchSessionService

    func recordSuccessfulAssistantTurn(
        authorization: LaunchAssistantTurnAuthorization
    ) async {
        guard let storedSession = authorization.session,
              !storedSession.entitlement.hasAccess else {
            return
        }

        if authorization.shouldUsePaywallTurn {
            do {
                _ = try await sessionService.activatePaywall(for: storedSession)
            } catch {
                ClickyLogger.error(
                    .app,
                    "Failed to persist launch paywall activation after paywall turn error=\(error.localizedDescription)"
                )
            }
        } else if authorization.shouldUseWelcomeTurn {
            do {
                _ = try await sessionService.markWelcomeDelivered(for: storedSession)
            } catch {
                ClickyLogger.error(
                    .app,
                    "Failed to persist launch welcome delivery after welcome turn error=\(error.localizedDescription)"
                )
            }
        } else if storedSession.trial?.status == "active" {
            do {
                let updatedSession = try await sessionService.consumeTrialCredit(
                    for: storedSession
                )
                if updatedSession.trial?.status == "armed" {
                    ClickyLogger.notice(
                        .app,
                        "Launch trial exhausted user=\(updatedSession.email) nextTurn=paywall"
                    )
                }
            } catch {
                ClickyLogger.error(
                    .app,
                    "Failed to persist launch trial credit consumption after assistant turn error=\(error.localizedDescription)"
                )
            }
        }
    }

    func recordPaywallFallback(
        authorization: LaunchAssistantTurnAuthorization
    ) async {
        guard authorization.shouldUsePaywallTurn,
              let storedSession = authorization.session else {
            return
        }

        do {
            _ = try await sessionService.activatePaywall(for: storedSession)
        } catch {
            ClickyLogger.error(
                .app,
                "Failed to persist launch paywall activation after paywall fallback error=\(error.localizedDescription)"
            )
        }
    }
}
