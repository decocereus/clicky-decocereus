//
//  ClickyTutorialImportCoordinator.swift
//  leanring-buddy
//
//  Runs tutorial extraction/import jobs and publishes draft state.
//

import Foundation

@MainActor
final class ClickyTutorialImportCoordinator {
    private let tutorialController: ClickyTutorialController
    private let backendURLProvider: @MainActor () -> String
    private let lessonCompiler: ClickyTutorialLessonCompiler
    private let clearConversationHistory: @MainActor () -> Void

    private var importTask: Task<Void, Never>?

    init(
        tutorialController: ClickyTutorialController,
        backendURLProvider: @escaping @MainActor () -> String,
        lessonCompiler: ClickyTutorialLessonCompiler,
        clearConversationHistory: @escaping @MainActor () -> Void
    ) {
        self.tutorialController = tutorialController
        self.backendURLProvider = backendURLProvider
        self.lessonCompiler = lessonCompiler
        self.clearConversationHistory = clearConversationHistory
    }

    func startImportFromPanel() {
        let trimmedURL = tutorialController.tutorialImportURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            tutorialController.tutorialImportStatusMessage = "Paste a YouTube URL to begin."
            return
        }

        guard let storedSession = ClickyAuthSessionStore.load() else {
            tutorialController.tutorialImportStatusMessage = "Sign in to import tutorials."
            return
        }

        guard Self.isSupportedYouTubeURL(trimmedURL) else {
            tutorialController.tutorialImportStatusMessage = "That doesn’t look like a valid YouTube URL."
            return
        }

        importTask?.cancel()
        tutorialController.isTutorialImportRunning = true
        tutorialController.tutorialImportStatusMessage = "Importing tutorial…"

        var draft = TutorialImportDraft(sourceURL: trimmedURL, status: .extracting)
        tutorialController.currentTutorialImportDraft = draft

        importTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let client = TutorialExtractionClient(
                    baseURL: backendURLProvider(),
                    sessionToken: storedSession.sessionToken
                )
                let startResponse = try await client.startExtraction(sourceURL: trimmedURL)
                draft.videoID = startResponse.videoID
                draft.extractionJobID = startResponse.jobID
                draft.updatedAt = Date()
                tutorialController.currentTutorialImportDraft = draft
                tutorialController.tutorialImportStatusMessage = "Extracting tutorial structure…"

                let snapshot = try await pollExtractionJob(
                    client: client,
                    jobID: startResponse.jobID
                )

                guard snapshot.status == "success" else {
                    throw TutorialExtractionClientError.unexpectedStatus(
                        code: 500,
                        message: snapshot.error ?? "Tutorial extraction failed."
                    )
                }

                let evidenceBundle = try await client.fetchEvidence(videoID: startResponse.videoID)
                draft.videoID = evidenceBundle.videoID
                draft.title = evidenceBundle.source.title
                draft.embedURL = evidenceBundle.source.embedURL
                draft.channelName = evidenceBundle.source.channel
                draft.durationSeconds = evidenceBundle.source.durationSeconds
                draft.thumbnailURL = evidenceBundle.source.thumbnailURL
                draft.evidenceBundle = evidenceBundle
                draft.status = .extracted
                draft.updatedAt = Date()
                tutorialController.currentTutorialImportDraft = draft
                tutorialController.tutorialImportStatusMessage = "Compiling tutorial steps…"

                draft.status = .compiling
                draft.updatedAt = Date()
                tutorialController.currentTutorialImportDraft = draft

                let compiledLessonDraft = try await lessonCompiler.compile(
                    evidenceBundle: evidenceBundle
                )
                draft.compiledLessonDraft = compiledLessonDraft
                draft.status = .ready
                draft.updatedAt = Date()
                tutorialController.currentTutorialImportDraft = draft
                tutorialController.tutorialSessionState = TutorialSessionState(
                    draftID: draft.id,
                    lessonDraft: compiledLessonDraft,
                    evidenceBundle: evidenceBundle,
                    currentStepIndex: 0,
                    isActive: false
                )
                clearConversationHistory()
                tutorialController.isTutorialImportRunning = false
                tutorialController.tutorialImportStatusMessage = "Tutorial ready."
            } catch {
                draft.status = .failed
                draft.extractionError = error.localizedDescription
                draft.updatedAt = Date()
                tutorialController.currentTutorialImportDraft = draft
                tutorialController.isTutorialImportRunning = false
                tutorialController.tutorialImportStatusMessage = error.localizedDescription
            }
        }
    }

    func retryImportFromPanel() {
        startImportFromPanel()
    }

    private func pollExtractionJob(
        client: TutorialExtractionClient,
        jobID: String
    ) async throws -> TutorialExtractionJobSnapshot {
        while true {
            try Task.checkCancellation()
            let snapshot = try await client.fetchJob(jobID: jobID)
            if snapshot.status == "success" || snapshot.status == "error" {
                return snapshot
            }
            try await Task.sleep(for: .seconds(1))
        }
    }

    static func isSupportedYouTubeURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host?.lowercased() else {
            return false
        }

        return ["youtube.com", "www.youtube.com", "youtu.be", "music.youtube.com"].contains(host)
    }
}
