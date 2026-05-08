//
//  ClickyTutorialStateStore.swift
//  leanring-buddy
//
//  Durable local storage for the current tutorial draft and session progress.
//

import Foundation

struct ClickyTutorialStateSnapshot: Codable, Sendable {
    var currentImportDraft: TutorialImportDraft?
    var sessionState: TutorialSessionState?
}

struct ClickyTutorialStateStore {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileURL: URL = Self.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> ClickyTutorialStateSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        guard let snapshot = try? decoder.decode(ClickyTutorialStateSnapshot.self, from: data) else {
            return nil
        }

        return Self.normalizedForLaunch(snapshot)
    }

    func save(_ snapshot: ClickyTutorialStateSnapshot) throws {
        if snapshot.currentImportDraft == nil && snapshot.sessionState == nil {
            clear()
            return
        }

        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    func clear() {
        try? fileManager.removeItem(at: fileURL)
    }

    private static func defaultFileURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let baseURL = applicationSupportURL
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("Clicky", isDirectory: true)
            .appendingPathComponent("tutorial-state.json")
    }

    private static func normalizedForLaunch(
        _ snapshot: ClickyTutorialStateSnapshot
    ) -> ClickyTutorialStateSnapshot {
        let restoredDraft = snapshot.currentImportDraft.map(normalizedDraftForLaunch)
        let restoredSession = normalizedSessionState(
            snapshot.sessionState,
            for: restoredDraft
        )

        return ClickyTutorialStateSnapshot(
            currentImportDraft: restoredDraft,
            sessionState: restoredSession
        )
    }

    private static func normalizedDraftForLaunch(
        _ draft: TutorialImportDraft
    ) -> TutorialImportDraft {
        switch draft.status {
        case .ready, .failed:
            return draft
        case .pending, .extracting, .extracted, .compiling:
            var interruptedDraft = draft
            interruptedDraft.status = .failed
            interruptedDraft.extractionError = draft.extractionError
                ?? draft.compileError
                ?? "Tutorial import was interrupted. Try again to continue."
            interruptedDraft.updatedAt = Date()
            return interruptedDraft
        }
    }

    private static func normalizedSessionState(
        _ sessionState: TutorialSessionState?,
        for draft: TutorialImportDraft?
    ) -> TutorialSessionState? {
        guard let sessionState,
              let draft,
              sessionState.draftID == draft.id,
              draft.compiledLessonDraft != nil,
              !sessionState.lessonDraft.steps.isEmpty else {
            return nil
        }

        let maximumStepIndex = sessionState.lessonDraft.steps.count - 1
        let clampedStepIndex = min(
            max(sessionState.currentStepIndex, 0),
            maximumStepIndex
        )

        return TutorialSessionState(
            draftID: sessionState.draftID,
            lessonDraft: sessionState.lessonDraft,
            evidenceBundle: sessionState.evidenceBundle,
            currentStepIndex: clampedStepIndex,
            isActive: sessionState.isActive
        )
    }
}
