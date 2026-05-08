//
//  CompanionPanelTutorialCards.swift
//  leanring-buddy
//
//  Tutorial-specific secondary cards for the menu-bar companion panel.
//

import SwiftUI

private struct CompanionPanelTutorialURLInput: View {
    @ObservedObject var tutorialController: ClickyTutorialController
    let placeholder: String
    let submit: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YouTube URL")
                .font(ClickyTypography.body(size: 13, weight: .semibold))
                .foregroundColor(contentTheme.textPrimary)

            CompanionPanelTutorialURLField(
                tutorialController: tutorialController,
                placeholder: placeholder,
                theme: theme,
                contentTheme: contentTheme,
                onSubmit: submit
            )
        }
    }
}

struct CompanionPanelTutorialEntryPointCard: View {
    let showsExplainer: Bool
    let startLearning: () -> Void
    let toggleExplainer: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    CompanionPanelSectionEyebrow("Learn")
                    Text("Turn a tutorial into a guided flow")
                        .font(ClickyTypography.section(size: 20))
                        .foregroundColor(contentTheme.textPrimary)
                    Text("Paste a YouTube URL and Clicky will teach it beside your cursor.")
                        .font(ClickyTypography.body(size: 12))
                        .foregroundColor(contentTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                CompanionPanelInlineStatus(label: "New", tone: .info)
            }

            if showsExplainer {
                Text("Clicky extracts the useful parts, compiles them into a lesson, then guides you step by step with inline video and voice help.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Button(action: startLearning) {
                    Text("Start Learning")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: toggleExplainer) {
                    Text("How it works")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
                .frame(width: 148)
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelTutorialImportEntryCard: View {
    @ObservedObject var tutorialController: ClickyTutorialController
    let startImport: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompanionPanelTutorialURLInput(
                tutorialController: tutorialController,
                placeholder: "https://youtube.com/watch?v=...",
                submit: startImport
            )

            Text("Clicky will extract the useful parts, compile a lesson, and guide you through it on your own screen.")
                .font(ClickyTypography.body(size: 12))
                .foregroundColor(contentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: startImport) {
                Text("Start Learning")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelTutorialImportMissingSetupCard: View {
    @ObservedObject var tutorialController: ClickyTutorialController
    let startImport: () -> Void
    let openStudio: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CompanionPanelTutorialURLInput(
                tutorialController: tutorialController,
                placeholder: "https://youtube.com/watch?v=dQw4w9WgXcQ",
                submit: startImport
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("The tutorial extraction service API key is missing.")
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)
                Text("Add it in Studio first, then come back here to start learning from tutorials.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(2)

            Button(action: openStudio) {
                Text("Open Studio")
                    .frame(maxWidth: .infinity)
            }
            .modifier(ClickyProminentActionStyle())
            .pointerCursor()
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelTutorialExtractingCard: View {
    @ObservedObject var tutorialController: ClickyTutorialController
    let cancel: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CompanionPanelSectionEyebrow("Current Step")
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.success.opacity(0.75))
                        .frame(width: 8, height: 8)
                    Text("Extracting transcript")
                        .font(ClickyTypography.body(size: 13, weight: .medium))
                        .foregroundColor(contentTheme.textPrimary)
                }

                ProgressView(value: extractionProgress)
                    .tint(theme.success)

                Text("Next: representative frames and structure.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
            }

            HStack {
                Button(action: cancel) {
                    Text("Cancel")
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Spacer()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var extractionProgress: Double {
        guard let draft = tutorialController.currentTutorialImportDraft else { return 0.22 }

        switch draft.status {
        case .extracting:
            return 0.48
        case .extracted:
            return 0.66
        case .compiling:
            return 0.84
        case .ready:
            return 1.0
        case .failed:
            return 0.18
        case .pending:
            return 0.08
        }
    }
}

struct CompanionPanelTutorialCompilingCard: View {
    let cancel: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CompanionPanelSectionEyebrow("Lesson Draft")
                Text("Building step titles, instructions, and verification hints…")
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(contentTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle().fill(contentTheme.textMuted.opacity(0.6)).frame(width: 6, height: 6)
                    Circle().fill(contentTheme.textMuted.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(contentTheme.textMuted.opacity(0.45)).frame(width: 6, height: 6)
                }
            }

            HStack {
                Button(action: cancel) {
                    Text("Cancel")
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Spacer()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelTutorialReadyCard: View {
    @ObservedObject var tutorialController: ClickyTutorialController
    let startLesson: () -> Void
    let openStudio: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CompanionPanelSectionEyebrow("Lesson Snapshot")
                Text(lessonTitle)
                    .font(ClickyTypography.body(size: 13, weight: .semibold))
                    .foregroundColor(contentTheme.textPrimary)
                Text(lessonSummaryLine)
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: startLesson) {
                    Text("Start Lesson")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var lessonTitle: String {
        tutorialController.currentTutorialImportDraft?.compiledLessonDraft?.title
            ?? tutorialController.currentTutorialImportDraft?.title
            ?? "Your guided lesson"
    }

    private var lessonSummaryLine: String {
        if let lessonDraft = tutorialController.currentTutorialImportDraft?.compiledLessonDraft {
            let stepCount = lessonDraft.steps.count
            return "\(stepCount) steps · \(tutorialController.currentTutorialImportDraft?.channelName ?? "guided help") · answer questions as you go"
        }

        return "Guided help is ready beside your cursor."
    }
}

struct CompanionPanelTutorialPlaybackCard: View {
    let repeatStep: () -> Void
    let rewind: () -> Void
    let advance: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CompanionPanelSectionEyebrow("Video Context")
                Text("Source clip available inline beside the cursor. Space to pause, arrows to seek, Escape to dismiss.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(action: repeatStep) {
                    Text("Repeat")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Button(action: rewind) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()

                Button(action: advance) {
                    Text("Next Step")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }
}

struct CompanionPanelTutorialFailedCard: View {
    @ObservedObject var tutorialController: ClickyTutorialController
    let retryImport: () -> Void
    let openStudio: () -> Void

    @Environment(\.clickyTheme) private var theme

    private var contentTheme: ClickyTheme {
        theme.contentSurfaceTheme
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                CompanionPanelSectionEyebrow("Failure Reason")
                Text(failureReason)
                    .font(ClickyTypography.body(size: 13))
                    .foregroundColor(contentTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Try again or inspect diagnostics in Studio.")
                    .font(ClickyTypography.body(size: 12))
                    .foregroundColor(contentTheme.textSecondary)
            }

            HStack(spacing: 10) {
                Button(action: retryImport) {
                    Text("Try Again")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickyProminentActionStyle())
                .pointerCursor()

                Button(action: openStudio) {
                    Text("Open Studio")
                        .frame(maxWidth: .infinity)
                }
                .modifier(ClickySecondaryGlassButtonStyle())
                .pointerCursor()
            }
        }
        .modifier(ClickyPanelContentCardStyle(padding: 16))
    }

    private var failureReason: String {
        tutorialController.currentTutorialImportDraft?.extractionError
            ?? tutorialController.currentTutorialImportDraft?.compileError
            ?? tutorialController.tutorialImportStatusMessage
            ?? "The extraction service returned an incomplete evidence bundle."
    }
}
