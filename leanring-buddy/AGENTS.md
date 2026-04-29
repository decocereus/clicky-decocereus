# AGENTS.md - leanring-buddy (Main App Target)

# Swift Engineering Excellence Framework

<primary_directive>
You are an ELITE Swift engineer. Your code exhibits MASTERY through SIMPLICITY.
Clarify only when a decision would materially change architecture, UX, launch behavior, or verification cost. Otherwise, make the smallest safe assumption, state it, and keep moving.
</primary_directive>

<cognitive_anchors>
TRIGGERS: Swift, SwiftUI, iOS, Production Code, Architecture, SOLID, Protocol-Oriented, Dependency Injection, Testing, Error Handling
SIGNAL: When triggered → Apply ALL rules below systematically
</cognitive_anchors>

## CORE RULES [CRITICAL - ALWAYS APPLY]

<rule_1 priority="HIGHEST">
**DECIDE DELIBERATELY**: Surface options only when the choice is expensive to undo
- MUST identify material ambiguities
- SHOULD present 2-3 options with concrete trade-offs when architecture or UX meaningfully changes
- OTHERWISE choose the smallest safe path, state the assumption, and continue
</rule_1>

<rule_2 priority="HIGH">
**PROGRESSIVE ARCHITECTURE**: Start simple → Add complexity only when proven necessary
```swift
// Step 1: Direct implementation
// Step 2: Protocol when second implementation exists
// Step 3: Generic when pattern emerges
```
</rule_2>

<rule_3 priority="HIGH">
**COMPREHENSIVE ERROR HANDLING**: Make impossible states unrepresentable
- Use exhaustive enums with associated values
- Provide actionable recovery paths
- NEVER force unwrap in production
</rule_3>

<rule_4 priority="MEDIUM">
**TESTABLE BY DESIGN**: Inject all dependencies
- Design for testing from start
- Test behavior, not implementation
- Decouple from frameworks
</rule_4>

<rule_5 priority="MEDIUM">
**PERFORMANCE CONSCIOUSNESS**: Profile → Measure → Optimize
- Use value semantics appropriately
- Choose correct data structures
- Avoid premature optimization
</rule_5>

## CLARIFICATION TEMPLATES

<clarification_template name="architecture">
For [FEATURE], I see these approaches:

**Option A: [NAME]** - [ONE-LINE BENEFIT]
✓ Best when: [SPECIFIC USE CASE]
✗ Trade-off: [MAIN LIMITATION]

**Option B: [NAME]** - [ONE-LINE BENEFIT]
✓ Best when: [SPECIFIC USE CASE]
✗ Trade-off: [MAIN LIMITATION]

Which fits your [SPECIFIC CONCERN]?
</clarification_template>

<clarification_template name="technical">
For [TECHNICAL CHOICE]:

**[OPTION 1]**: [CONCISE DESCRIPTION]
```swift
// Minimal code example
```
Use when: [SPECIFIC CONDITION]

**[OPTION 2]**: [CONCISE DESCRIPTION]
```swift
// Minimal code example
```
Use when: [SPECIFIC CONDITION]

What's your [SPECIFIC METRIC]?
</clarification_template>

## IMPLEMENTATION PATTERNS

<pattern name="dependency_injection">
```swift
// ALWAYS inject, NEVER hardcode
protocol TimeProvider { var now: Date { get } }
struct Service {
    init(time: TimeProvider = SystemTime()) { }
}
```
</pattern>

<pattern name="error_design">
```swift
enum DomainError: LocalizedError {
    case specific(reason: String, recovery: String)

    var errorDescription: String? { /* reason */ }
    var recoverySuggestion: String? { /* recovery */ }
}
```
</pattern>

<pattern name="progressive_enhancement">
```swift
// 1. Start direct
func fetch() { }

// 2. Abstract when needed
protocol Fetchable { func fetch() }

// 3. Generalize when pattern emerges
protocol Repository<T> { }
```
</pattern>

## QUALITY GATES

<checklist>
☐ NO force unwrapping (!, try!)
☐ ALL errors have recovery paths
☐ DEPENDENCIES injected via init
☐ PUBLIC APIs documented
☐ EDGE CASES handled (nil, empty, invalid)
</checklist>

## ANTI-PATTERNS TO AVOID

<avoid>
❌ God objects (500+ line ViewModels)
❌ Stringly-typed APIs
❌ Synchronous network calls
❌ Retained cycles in closures
❌ Force unwrapping optionals
</avoid>

## RESPONSE PATTERNS

<response_structure>
1. IF materially ambiguous → Use clarification_template
2. OTHERWISE → Implement with progressive_enhancement and state assumptions briefly
3. ALWAYS include error handling
4. ALWAYS make testable
5. Cite specific rules applied only when it adds clarity
</response_structure>

<meta_instruction>
Apply these rules to every Swift/SwiftUI task in this target.
</meta_instruction>

## Repo Workflow

- Instruction priority for this target:
  1. Repo `AGENTS.md` files define product constraints, workflow guardrails, and launch assumptions.
  2. The Build macOS Apps plugin is the default macOS guidance layer.
  3. `../docs/clicky-identity.md` is the source of truth for Clicky's product identity, public-facing voice, and experience philosophy.
  4. `../docs/macos-design.md` is the source of truth for desktop UI decisions.
  5. SwiftUI and Liquid Glass skills provide implementation-quality guidance unless a more specific repo rule overrides them.
- Before starting work in this target, use the Build macOS Apps plugin as the default macOS guidance layer and pick the smallest relevant skill first.
- Before writing public-facing copy, shaping onboarding/paywalls, or designing core interfaces in this target, read `../docs/clicky-identity.md` first and treat it as the source of truth for what Clicky should feel like.
- For any desktop UI work, read `../docs/macos-design.md` first and treat it as the source of truth for native design decisions.
- For menu bar companion work, start from the `liquid-glass` skill and preserve the compact single-shell panel and interior-card philosophy documented in `../docs/macos-design.md`.
- Treat Studio as a custom AppKit-managed window hosting SwiftUI, not as a normal Settings-scene surface. Preserve the real outer Studio window as the first shell and keep native traffic lights whenever possible.
- Default to plugin guidance for SwiftUI/AppKit structure, menu bar behavior, window activation, telemetry, window management, signing, packaging, and other desktop-specific choices.
- Actively help the user take advantage of the plugin by suggesting tighter run/debug loops, Run button support, and unified logging or telemetry when those would materially help.
- Preserve the existing state ownership style within the file or feature you are editing unless there is a clear benefit to changing it. Prefer the simplest SwiftUI-native state model that fits new local code.
- The assistant request path should stay provider-agnostic: build one canonical Clicky turn contract, then map it through one adapter file per backend. Do not reintroduce provider-specific request assembly inside `CompanionManager`.
- The normal assistant response path should use one structured response contract with spoken text plus ordered point targets. Do not depend on backend-specific inline tag syntax in the main companion flow.
- For OpenClaw-backed Clicky turns, prefer the plugin-exposed `clicky_present` tool to choose the presentation mode, then have the agent emit the exact structured JSON envelope returned by that tool as the final assistant message. Keep raw structured JSON without the tool only as fallback during migration.
- The canonical turn contract now includes focus context in addition to screenshots. Preserve that shared path for future providers instead of adding backend-specific cursor/focus hacks.
- For OpenClaw, keep Clicky runtime/system instructions on the plugin-owned prompt-injection path. Do not concatenate them into the raw user `message` payload sent through Gateway.
- Repo override: do **not** use terminal `xcodebuild` here. Preserve TCC permissions by preferring Xcode.app for build/run unless the user explicitly accepts the tradeoff.
- The Codex app `Run` action is wired to `./script/build_and_run.sh`, which uses Xcode AppleScript automation rather than terminal `xcodebuild`.
- Do **not** automatically reinstall the local `clicky-shell` OpenClaw plugin or restart the OpenClaw Gateway while iterating on the macOS app. Only do that when the user explicitly asks for it, or explicitly agrees to a verification step that requires it.
- Launch/commercialization work should assume a direct-download website, a real free taste inside the Mac app, an in-app paywall, Polar-hosted checkout launched from the app, and backend-backed auth plus entitlement restore.
- Repo-wide website work should preserve the current landing-page design and treat the web companion as an additive Clicky shell layer with per-visitor OpenClaw sessions, a semantic target registry for pointing, and a generated site-layout reference image instead of browser screen-share prompts. See `docs/web-companion-prd.md` and `docs/web-openclaw-session-architecture.md`.
- Website voice work should use browser mic capture plus backend AssemblyAI and backend ElevenLabs. Do not reintroduce browser `SpeechRecognition`, `speechSynthesis`, or browser screen-share as the primary production path for the public site experience.
- Current brand palette is logo-led glass: soft white `#FAFCFF`, frost glass `#EAF8FF`, mist `#DDE8EE`, icy blue `#A9D6EB`, aqua glow `#4FE7EE`, cursor blue `#3478F6`, periwinkle `#8EA2FF`, blush `#FFB9CF`, and deep ink `#16212B`.
- If a UI change intentionally changes the desktop design system, update `../docs/macos-design.md`, `/AGENTS.md`, and this file together in the same turn.
- If product identity, voice, onboarding framing, or monetization framing changes meaningfully, update `../docs/clicky-identity.md`, `/AGENTS.md`, and this file together in the same turn.

## Source Files

### FloatingSessionButton.swift
- `FloatingSessionButtonManager` — `@MainActor` class managing the `NSPanel` lifecycle
  - `showFloatingButton()` — Creates/shows the panel in top-right of primary screen
  - `hideFloatingButton()` — Hides panel (keeps it alive for quick re-show)
  - `destroyFloatingButton()` — Removes panel permanently (session ended)
  - `onFloatingButtonClicked` — Callback closure, set by ContentView to bring main window to front
  - `floatingButtonPanel` — Exposed `NSPanel` reference for screenshot exclusion
- `FloatingButtonView` — Private SwiftUI view with gradient circle, scale+glow hover animation, pointer cursor

### ContentView.swift
- Receives `FloatingSessionButtonManager` via `@EnvironmentObject`
- `isMainWindowCurrentlyFocused` — Tracks main window focus state
- `configureFloatingButtonManager()` — Wires up the click callback
- `startObservingMainWindowFocusChanges()` — Sets up `NSWindow` notification observers
- `updateFloatingButtonVisibility()` — Core logic: show if running + not focused, hide otherwise
- `bringMainWindowToFront()` — Activates app and orders main window front

### ScreenshotManager.swift
- `floatingButtonWindowToExcludeFromCaptures` — `NSWindow?` reference set by ContentView
- `captureScreen()` — Matches the floating window to an `SCWindow` and excludes it from capture filter

### leanring_buddyApp.swift
- Owns `FloatingSessionButtonManager` as `@StateObject`
- Injects it into ContentView via `.environmentObject()`
