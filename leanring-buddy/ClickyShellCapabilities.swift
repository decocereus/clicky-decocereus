//
//  ClickyShellCapabilities.swift
//  leanring-buddy
//
//  Versioned shell capability contract shared by the Clicky app.
//

import Foundation

enum ClickyShellCapabilities {
    static let shellProtocolVersion = "1"
    static let shellCapabilityVersion = "1"

    static let capabilityIdentifiers = [
        "push_to_talk",
        "screen_capture",
        "cursor_overlay",
        "local_tts",
        "point_tag_v1",
    ]

    static let cursorPointingProtocol = "point-tag-v1"
    static let screenContextTransport = "attached-images"
    static let speechOutputMode = "clicky-local-tts"
    static let supportsInlineTextBubble = false
}
