# Plan: Track B - Split Tracks

Track B is no longer a single umbrella plan.

For launch, the broad Teach Mode and workflow-automation path has been deferred rather than kept half-in and half-out of scope. The active planning docs in the main worktree are now:

- `plans/focus-mode-implementation-path.md`
- `plans/youtube-tutorial-flow.md`

## Why this split exists

- Focus Mode is still important, but it is a separate product loop from tutorial import and guided learning.
- The YouTube/tutorial flow is still relevant to launch exploration, but it should not drag Teach Mode and workflow replay complexity back into scope.
- The previous combined Track B plan had become too broad and was encouraging work on features we are intentionally not shipping right now.

## Current decision

- **Keep**: Focus Mode planning.
- **Keep**: YouTube tutorial import and guided tutorial planning.
- **Defer**: Teach Mode capture, workflow authoring, workflow execution, and replay automation.

## Status update

The YouTube tutorial track is no longer planning-only.

What now exists in code:

- tutorial URL entry in the Mac companion panel
- authenticated backend tutorial proxy routes
- extraction polling and evidence fetch
- lesson compilation through the selected assistant backend
- inline YouTube playback beside the cursor
- tutorial-mode turns for step progression and in-context help

What is still missing is mainly persistence, polish, and real end-to-end verification.

If Teach Mode returns later, it should come back as a fresh plan with a tighter wedge and clearer launch tradeoffs.
