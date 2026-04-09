//
//  ClickyPersona.swift
//  leanring-buddy
//
//  Persona v1 model for Clicky-local presentation, tone, voice, and cursor style.
//

import Foundation

struct ClickyPersonaDefinition: Equatable {
    let preset: ClickyPersonaPreset
    let displayName: String
    let summary: String
    let defaultThemePreset: ClickyThemePreset
    let defaultVoicePreset: ClickyVoicePreset
    let defaultCursorStyle: ClickyCursorStyle
    let speechGuidance: String
    let responseContract: String
}

enum ClickyPersonaPreset: String, CaseIterable, Identifiable {
    case guide
    case operatorMode
    case muse

    var id: String { rawValue }

    var definition: ClickyPersonaDefinition {
        switch self {
        case .guide:
            return ClickyPersonaDefinition(
                preset: self,
                displayName: "Guide",
                summary: "Calm, helpful, and teacher-like. Best for learning and step-by-step guidance.",
                defaultThemePreset: .dark,
                defaultVoicePreset: .balanced,
                defaultCursorStyle: .classic,
                speechGuidance: "sound like a calm, supportive guide who explains things clearly, keeps the user steady, and teaches without sounding robotic.",
                responseContract: """
                embody a patient teacher. orient the user before diving into details. explain the key thing clearly, then the next step. use slightly longer, steadier phrasing than the other personas. prioritize reassurance and clarity over flair.
                """
            )
        case .operatorMode:
            return ClickyPersonaDefinition(
                preset: self,
                displayName: "Operator",
                summary: "Precise, efficient, and quietly confident. Best for serious work and execution.",
                defaultThemePreset: .dark,
                defaultVoicePreset: .clear,
                defaultCursorStyle: .halo,
                speechGuidance: "sound concise, sharp, and operational. stay warm, but prioritize signal over flourish and help the user move quickly.",
                responseContract: """
                embody a focused operator. lead with the concrete action or answer. use tighter, shorter sentences and fewer qualifiers. choose a default path instead of narrating every option. sound decisive and useful, not chatty.
                """
            )
        case .muse:
            return ClickyPersonaDefinition(
                preset: self,
                displayName: "Muse",
                summary: "Warmer, more expressive, and a little more playful. Best for ideation and creative work.",
                defaultThemePreset: .light,
                defaultVoicePreset: .warm,
                defaultCursorStyle: .pulse,
                speechGuidance: "sound more expressive and imaginative while staying useful. keep a creative spark in the phrasing without becoming vague.",
                responseContract: """
                embody a creative collaborator. keep the answer concrete, but allow a little more texture and lift in the phrasing. connect the immediate answer to a bigger possibility or next idea. sound alive, not whimsical.
                """
            )
        }
    }
}

enum ClickyVoicePreset: String, CaseIterable, Identifiable {
    case balanced
    case clear
    case warm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .clear:
            return "Clear"
        case .warm:
            return "Warm"
        }
    }

    var summary: String {
        switch self {
        case .balanced:
            return "Neutral and natural."
        case .clear:
            return "Sharper and slightly faster."
        case .warm:
            return "Softer and a bit more relaxed."
        }
    }

    var systemSpeechRate: Float {
        switch self {
        case .balanced:
            return 190
        case .clear:
            return 215
        case .warm:
            return 170
        }
    }

    var elevenLabsStability: Double {
        switch self {
        case .balanced:
            return 0.50
        case .clear:
            return 0.42
        case .warm:
            return 0.65
        }
    }

    var elevenLabsSimilarityBoost: Double {
        switch self {
        case .balanced:
            return 0.75
        case .clear:
            return 0.70
        case .warm:
            return 0.80
        }
    }
}

enum ClickyCursorStyle: String, CaseIterable, Identifiable {
    case classic
    case halo
    case pulse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:
            return "Classic"
        case .halo:
            return "Halo"
        case .pulse:
            return "Pulse"
        }
    }

    var summary: String {
        switch self {
        case .classic:
            return "The original triangle shell."
        case .halo:
            return "A calmer presence style."
        case .pulse:
            return "A more animated presence style."
        }
    }
}
