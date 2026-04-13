# Studio Redesign Options

Status note:

- the current `CompanionStudioNextView` already reflects part of this redesign direction
- this doc should now be treated as design exploration and cleanup guidance rather than a pure future-state brainstorm

> Three distinct UI directions for Clicky's Studio panel, aligned to the current web app visual language and the launch product direction. In every option below, diagnostics and test controls are removed from the main user-facing flow and live in a dedicated support/debug surface.

## Shared Principles

These are non-negotiable across all three directions:

- Diagnostics does not live in the primary product flow.
- Credit controls, paywall test toggles, shell registration buttons, and other debug-only actions move into a dedicated support/debug panel.
- The main Studio should feel production-ready, not like an internal control room.
- The current web app's visual language should carry through:
  - warm editorial backgrounds
  - serif-led hierarchy
  - soft lavender / sage / rose accents
  - elegant motion instead of noisy animation
- Use system-native macOS structure first, then add custom Liquid Glass where it actually helps.

## Direction 1: Editorial Sidebar

### Summary

This direction keeps the current sidebar/detail architecture, but makes it feel like a polished editorial control center instead of a settings dump.

### Structure

- Left sidebar:
  - `Companion`
  - `Voice & Persona`
  - `Connection`
  - `Launch Access`
  - `Support`
- Main detail pane:
  - one strong hero header
  - 2–4 focused glass cards
  - each card owns one coherent concept

### Visual language

- Sidebar remains compact and calm, using near-native source-list behavior.
- Detail pane uses large serif titles inspired by the web hero.
- Cards use lightly tinted Liquid Glass:
  - lavender for voice/persona
  - sage for connection/ready states
  - rose for warnings/locked states
- Background uses subtle warm material, not heavy blur.

### Motion

- Sidebar selection morphs with `glassEffectID`.
- Cards fade/slide in with short stagger.
- Status pills softly pulse when state changes.
- Locked/paywall state gets a slow suspended shimmer rather than a flashing warning.

### Diagnostics strategy

- `Support` opens a diagnostics-only detail pane.
- All test buttons live there:
  - activate trial
  - consume credit
  - force paywall
  - refresh entitlement
  - export report
- No debug controls appear in `Launch Access`.

### Pros

- Lowest-risk refactor from the current implementation.
- Fits macOS `NavigationSplitView` well.
- Easy to stage incrementally.

### Cons

- Still feels like a settings app if we are not careful with hierarchy.
- Less dramatic than a more custom dashboard approach.

## Direction 2: Floating Chapters

### Summary

This direction turns Studio into a sequence of full-width “chapters” inside one scrollable glass canvas, closer to the web app’s section-based storytelling.

### Structure

- Sidebar becomes minimal chapter navigation:
  - `What Clicky Is`
  - `How It Sounds`
  - `How It Connects`
  - `How You Unlock It`
  - `Support`
- Each chapter is a large panel with artwork, copy, and one primary action.

### Visual language

- Stronger carryover from the website.
- More breathing room and larger typography.
- One dominant accent per chapter.
- Hero-like composition with mixed text + illustrative preview blocks.

### Motion

- Chapter transitions feel like soft scroll snaps.
- Floating art/preview surfaces move with slow drift similar to the web cards.
- Liquid Glass buttons subtly expand when hovered.
- When the user enters `Support`, the vibe intentionally changes from poetic to technical.

### Diagnostics strategy

- Diagnostics becomes a separate “Support chapter”.
- It is visually colder and more utilitarian.
- All debug affordances live there, clearly separated from the product narrative.

### Pros

- Strongest alignment with the current web app.
- Makes Studio feel like part of the product brand, not just a settings pane.
- Good for onboarding and paywall explanation.

### Cons

- More custom layout work.
- Risk of feeling too marketing-like if not grounded with enough utility.

## Direction 3: Command Deck

### Summary

This direction treats Studio more like a premium desktop control deck with grouped controls, status clusters, and a dedicated support inspector.

### Structure

- Main content uses a split dashboard:
  - top summary rail
  - left content column for setup and preferences
  - right inspector column for status, access, and context
- `Support` opens as a separate inspector-style mode or sheet.

### Visual language

- More technical than the editorial direction, but still elegant.
- Smaller typography overall, with strategic large section titles.
- Strong glass grouping and toolbar-level affordances.
- Better for power users while still keeping debug actions out of sight by default.

### Motion

- Tile groups share one `GlassEffectContainer`.
- Controls get interactive glass bounce on hover and press.
- Inspector cards animate state transitions with semantic tint changes.
- Locked/paywall state re-colors the access cluster and dims the rest of the deck.

### Diagnostics strategy

- Diagnostics is not a sidebar item.
- It opens from a small `Support Mode` or `Debug` affordance and reveals an inspector or sheet.
- Debug/test controls live there only.

### Pros

- Best for dense state and operational clarity.
- Most scalable if Studio grows.
- Strong fit for launch access, auth, billing, and connection state.

### Cons

- Less emotionally distinctive than the chapter approach.
- Can drift toward “pro tool” if not softened with the current brand language.

## Recommendation

I recommend **Direction 1: Editorial Sidebar** as the implementation target.

Why:

- It preserves the best part of the current macOS architecture: `NavigationSplitView`.
- It lets us cleanly separate diagnostics into `Support` without redesigning the whole app as a custom scroll experience.
- It can still borrow the web app's warmth, serif hierarchy, and soft motion.
- It is the fastest path to “production-ready and clean” without losing momentum.

## Detailed Recommendation

### New sidebar model

- `Companion`
  - product-facing state only
  - no test controls
- `Voice & Persona`
  - voice, cursor, persona, theme
- `Connection`
  - OpenClaw / backend / account connection state
- `Launch Access`
  - sign-in
  - entitlement
  - purchase
  - restore/refresh
  - no trial manipulation buttons
- `Support`
  - diagnostics
  - exports
  - test toggles
  - credit/paywall simulation

### Main user-facing cards

For `Launch Access`, I would reduce it to:

- Account status
- Entitlement status
- Trial status
- Purchase action
- Restore/refresh action

Everything else moves out.

### Support-only controls

Move these into `Support`:

- activate trial
- consume credit
- activate paywall
- refresh trial
- refresh entitlement if we still want it as a debug tool
- shell registration and raw summary controls
- any OpenClaw raw identity/debug state that normal users do not need

## Motion and Liquid Glass Notes

Across the chosen direction:

- Use one `GlassEffectContainer` for related controls in each card cluster.
- Use semantic tint only:
  - sage for healthy/connected
  - lavender for active/productive
  - rose for warning/locked
- Animate:
  - section switch
  - card reveal
  - status pill state changes
  - locked/paywall state transition
- Avoid:
  - giant blur slabs
  - dark opaque shells over system materials
  - putting every row in custom cards

## Implementation Order

1. Restructure the sidebar information architecture.
2. Move all debug/test controls into `Support`.
3. Simplify `Launch Access` to user-facing actions only.
4. Restyle the main detail cards with stronger hierarchy and cleaner grouping.
5. Add Liquid Glass interaction polish and state transitions.
6. Only then refine the diagnostics/support visuals.

## Immediate Next UI Task

If we implement this recommendation, the next concrete UI refactor should be:

1. Rename/reframe `Diagnostics` as `Support`
2. Move all test buttons out of `Launch Access`
3. Reduce `Launch Access` to account, entitlement, trial, purchase, restore
4. Restyle those surfaces with the web app’s editorial + soft-glass language
