//
//  TutorialImportModels.swift
//  leanring-buddy
//
//  Local-first models for importing YouTube tutorials through the
//  external fast extraction service and compiling them into Clicky
//  lesson drafts.
//

import Foundation

enum TutorialImportStatus: String, Codable, Sendable {
    case pending
    case extracting
    case extracted
    case compiling
    case ready
    case failed
}

enum TutorialImportStructureSource: String, Codable, Sendable {
    case youtubeChapters = "youtube_chapters"
    case syntheticFromCaptions = "synthetic_from_captions"
    case fallbackMediaAnalysis = "fallback_media_analysis"
}

enum TutorialImportTranscriptSource: String, Codable, Sendable {
    case youtubeSubtitles = "youtube_subtitles"
    case youtubeAutoCaptions = "youtube_auto_captions"
}

enum TutorialImportVisualSource: String, Codable, Sendable {
    case youtubeStoryboard = "youtube_storyboard"
    case youtubeThumbnails = "youtube_thumbnails"
    case downloadedFrames = "downloaded_frames"
}

enum TutorialImportQualityLevel: String, Codable, Sendable {
    case fast
    case enhanced
    case fallback
}

struct TutorialImportDraft: Identifiable, Codable, Sendable {
    let id: UUID
    var sourceURL: String
    var videoID: String?
    var title: String?
    var embedURL: String?
    var channelName: String?
    var durationSeconds: Int?
    var thumbnailURL: String?
    var extractionJobID: String?
    var status: TutorialImportStatus
    var extractionError: String?
    var compileError: String?
    var evidenceBundle: TutorialEvidenceBundle?
    var compiledLessonDraft: TutorialLessonDraft?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sourceURL: String,
        videoID: String? = nil,
        title: String? = nil,
        embedURL: String? = nil,
        channelName: String? = nil,
        durationSeconds: Int? = nil,
        thumbnailURL: String? = nil,
        extractionJobID: String? = nil,
        status: TutorialImportStatus = .pending,
        extractionError: String? = nil,
        compileError: String? = nil,
        evidenceBundle: TutorialEvidenceBundle? = nil,
        compiledLessonDraft: TutorialLessonDraft? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.videoID = videoID
        self.title = title
        self.embedURL = embedURL
        self.channelName = channelName
        self.durationSeconds = durationSeconds
        self.thumbnailURL = thumbnailURL
        self.extractionJobID = extractionJobID
        self.status = status
        self.extractionError = extractionError
        self.compileError = compileError
        self.evidenceBundle = evidenceBundle
        self.compiledLessonDraft = compiledLessonDraft
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TutorialEvidenceBundle: Codable, Sendable {
    let videoID: String
    let source: TutorialEvidenceSource
    let transcript: TutorialEvidenceTranscript
    let visualContext: TutorialEvidenceVisualContext
    let structureSource: TutorialImportStructureSource
    let structureMarkers: [TutorialStructureMarker]
    let quality: TutorialEvidenceQuality
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case videoID = "video_id"
        case source
        case transcript
        case visualContext = "visual_context"
        case structureSource = "structure_source"
        case structureMarkers = "structure_markers"
        case quality
        case createdAt = "created_at"
    }
}

struct TutorialEvidenceSource: Codable, Sendable {
    let url: String
    let embedURL: String
    let title: String
    let durationSeconds: Int
    let channel: String?
    let thumbnailURL: String?

    private enum CodingKeys: String, CodingKey {
        case url
        case embedURL = "embed_url"
        case title
        case durationSeconds = "duration_seconds"
        case channel
        case thumbnailURL = "thumbnail_url"
    }
}

struct TutorialEvidenceTranscript: Codable, Sendable {
    let source: TutorialImportTranscriptSource
    let language: String
    let segments: [TutorialTranscriptSegment]
}

struct TutorialTranscriptSegment: Codable, Sendable {
    let startSeconds: Double
    let endSeconds: Double
    let text: String

    private enum CodingKeys: String, CodingKey {
        case startSeconds = "start_seconds"
        case endSeconds = "end_seconds"
        case text
    }
}

struct TutorialEvidenceVisualContext: Codable, Sendable {
    let source: TutorialImportVisualSource
    let frames: [TutorialVisualFrame]

    private enum CodingKeys: String, CodingKey {
        case source
        case frames
    }
}

struct TutorialVisualFrame: Codable, Sendable {
    let url: String
    let width: Int?
    let height: Int?
    let label: String?
}

struct TutorialStructureMarker: Codable, Sendable {
    let startSeconds: Double
    let endSeconds: Double
    let title: String
    let confidence: Double
    let source: String
    let visualAnchorTimestamps: [Int]

    private enum CodingKeys: String, CodingKey {
        case startSeconds = "start_seconds"
        case endSeconds = "end_seconds"
        case title
        case confidence
        case source
        case visualAnchorTimestamps = "visual_anchor_timestamps"
    }
}

struct TutorialEvidenceQuality: Codable, Sendable {
    let level: TutorialImportQualityLevel
    let hasCreatorChapters: Bool
    let hasCaptions: Bool
    let hasVisualAnchors: Bool

    private enum CodingKeys: String, CodingKey {
        case level
        case hasCreatorChapters = "has_creator_chapters"
        case hasCaptions = "has_captions"
        case hasVisualAnchors = "has_visual_anchors"
    }
}

struct TutorialLessonDraft: Codable, Sendable {
    let title: String
    let summary: String
    let steps: [TutorialLessonStep]
    let createdAt: Date
}

struct TutorialSessionState: Codable, Sendable {
    let draftID: UUID
    let lessonDraft: TutorialLessonDraft
    let evidenceBundle: TutorialEvidenceBundle
    var currentStepIndex: Int
    var isActive: Bool
}

struct TutorialLessonStep: Identifiable, Codable, Sendable {
    let id: UUID
    let title: String
    let instruction: String
    let verificationHint: String?
    let sourceTimeRange: TutorialLessonTimeRange?
    let sourceVideoPromptTimestamp: Int?

    init(
        id: UUID = UUID(),
        title: String,
        instruction: String,
        verificationHint: String? = nil,
        sourceTimeRange: TutorialLessonTimeRange? = nil,
        sourceVideoPromptTimestamp: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.verificationHint = verificationHint
        self.sourceTimeRange = sourceTimeRange
        self.sourceVideoPromptTimestamp = sourceVideoPromptTimestamp
    }
}

struct TutorialLessonTimeRange: Codable, Sendable {
    let startSeconds: Double
    let endSeconds: Double
}
