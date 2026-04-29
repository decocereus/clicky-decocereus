//
//  ClickyShellCapabilities.swift
//  leanring-buddy
//
//  Versioned shell capability contract shared by the Clicky app.
//

import Foundation

enum ClickyShellCapabilities {
    static let shellProtocolVersion = "1"
    static let shellCapabilityVersion = "2"

    static let capabilityIdentifiers = [
        "push_to_talk",
        "screen_capture",
        "cursor_overlay",
        "local_tts",
        "structured_response_v1",
        "computer_use_observe",
        "computer_use_locate",
        "computer_use_locate_many",
        "computer_use_click",
        "computer_use_type_text",
        "computer_use_press_key",
        "computer_use_scroll",
        "computer_use_set_value",
        "computer_use_secondary_action",
        "computer_use_drag",
        "computer_use_resize_window",
        "computer_use_set_window_frame",
    ]

    static let cursorPointingProtocol = "structured-response-v1"
    static let screenContextTransport = "attached-images"
    static let speechOutputMode = "clicky-local-tts"
    static let supportsInlineTextBubble = false
}
