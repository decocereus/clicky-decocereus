# ElevenLabs Handoff Prompt

Use this prompt as the starting context for a new coding agent taking over the remaining ElevenLabs work in Clicky.

## Prompt

You are taking over the remaining ElevenLabs work for the macOS app in this repository:

- repo: `/Users/amartyasingh/Documents/projects/clicky-decocereus`
- app target: `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy`

Your job is to finish the remaining **ElevenLabs BYO voice polish** for Clicky on macOS.

### Important constraints

- Use the **Build macOS Apps** plugin skills and relevant macOS skills where useful.
- Prefer the macOS skills for:
  - build/run/debug
  - unified logging / telemetry
  - SwiftUI/macOS patterns
- **Do not use `xcodebuild` from the terminal**. This repo explicitly avoids that because it can mess with TCC permissions.
- Build through **Xcode-driven AppleScript** or the same Xcode scheme-action workflow already used in this thread.
- Do **not** reinstall the OpenClaw plugin or restart the OpenClaw Gateway unless explicitly asked.
- If the git worktree contains unrelated changes when you start, leave them alone unless they are required for this task.

### Current product state

The app already supports:

- system speech fallback by default
- local BYO ElevenLabs API key storage using Keychain
- fetching available ElevenLabs voices directly from ElevenLabs
- switching the speech provider between `System` and `ElevenLabs`
- selecting an ElevenLabs voice in Studio

The current ElevenLabs implementation is **functional**, but it still needs polish and debugging ergonomics.

### Relevant files

- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/CompanionManager.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/CompanionStudioView.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ElevenLabsTTSClient.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ElevenLabsService.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ClickySecrets.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/ClickyLogger.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/CompanionPanelView.swift`
- `/Users/amartyasingh/Documents/projects/clicky-decocereus/leanring-buddy/CompanionStudioView.swift`

### What is already implemented

1. **Local-only secret storage**
   - ElevenLabs API key is stored locally in Keychain.
   - It is not intended to be sent to our backend.

2. **Provider model**
   - Speech provider can be either:
     - `System`
     - `ElevenLabs`
   - Provider state is persisted locally.

3. **Voice list**
   - Voices can be loaded from the ElevenLabs API.
   - Selected voice id/name is persisted locally.

4. **Runtime usage**
   - If `System` is selected, local system speech is used.
   - If `ElevenLabs` is selected and configured, direct ElevenLabs TTS is used.

5. **Diagnostics**
   - There is already a diagnostics/logging system in the app.

### Remaining ElevenLabs work

Focus only on this slice:

1. **Make the Voice settings UX clearer**
   - Ensure the `System` vs `ElevenLabs` choice is obvious.
   - Make the ElevenLabs section visually unmistakable when selected.
   - Make the “local-only / stored in Keychain / not uploaded to us” message very clear and friendly.

2. **Voice preview**
   - Add a way to preview the currently selected ElevenLabs voice without requiring a full assistant turn.
   - Preview can use a fixed sample phrase.
   - Preview should work for both:
     - system speech
     - ElevenLabs voice

3. **Error states**
   - Improve UI states for:
     - missing API key
     - invalid API key
     - voice load failure
     - no voices available
     - selected provider falling back to system speech

4. **Diagnostics enrichment**
   - Ensure diagnostics/logs include enough speech context to debug issues:
     - selected speech provider
     - selected voice name/id
     - whether fallback to system happened
     - whether preview succeeded or failed

5. **Polish**
   - Tighten the Voice card copy and hierarchy.
   - Keep it user-facing and minimal.
   - Do not turn it into a developer console.

### Suggested terminal setup

Open a terminal/session for live app logs:

```bash
/usr/bin/log stream --style compact --level debug --predicate 'process == "Clicky" AND subsystem == "com.yourcompany.leanring-buddy"'
```

If you want a narrower terminal just for voice-related app logs:

```bash
/usr/bin/log stream --style compact --level debug --predicate 'process == "Clicky" AND subsystem == "com.yourcompany.leanring-buddy" AND (category == "audio" OR category == "agent" OR category == "ui")'
```

If you want a quick recent snapshot instead of streaming:

```bash
/usr/bin/log show --last 10m --style compact --predicate 'process == "Clicky" AND subsystem == "com.yourcompany.leanring-buddy"'
```

### Build / relaunch workflow

Use Xcode via AppleScript, not `xcodebuild`.

Follow the same approach already used in this repo’s thread:

- open the `.xcodeproj`
- wait for workspace load
- invoke Xcode’s `build` AppleScript command
- read `last scheme action result`
- relaunch the built app from DerivedData if the build succeeds

### Success criteria

The task is complete when:

- a user can clearly switch between `System` and `ElevenLabs`
- a user can save an ElevenLabs API key locally
- a user can load and choose voices
- a user can preview the chosen voice
- failure/fallback states are understandable
- diagnostics are good enough to debug voice issues quickly
- the app builds and relaunches successfully after the changes

### What not to do

- do not add auth/billing/backend work in this slice
- do not touch OpenClaw plugin/runtime behavior unless strictly needed
- do not expand into general provider infrastructure beyond what is necessary for ElevenLabs polish
- do not use terminal `xcodebuild`

