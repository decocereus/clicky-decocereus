# Hi, this is Clicky.
It's an AI teacher that lives as a buddy next to your cursor. It can see your screen, talk to you, and even point at stuff. Kinda like having a real teacher next to you.

Download it [here](https://www.clicky.so/) for free.

Here's the [original tweet](https://x.com/FarzaTV/status/2041314633978659092) that kinda blew up for a demo for more context.

![Clicky — an ai buddy that lives on your mac](clicky-demo.gif)

This is the open-source version of Clicky for those that want to hack on it, build their own features, or just see how it works under the hood.

## Current status

This repo is well past the original demo stage.

Implemented today:

- macOS menu bar companion with a floating panel and a custom Studio window
- provider-agnostic assistant pipeline with `Claude`, `Codex`, and `OpenClaw`
- push-to-talk audio capture, screen capture, cursor pointing, and local speech playback
- backend-backed auth, entitlements, launch trial credits, paywall flow, and Polar checkout plumbing
- OpenClaw `clicky-shell` plugin scaffold plus real shell registration, heartbeat, and session binding
- website companion with per-visitor sessions, section-aware context, optional voice input, and backend-mediated OpenClaw routing
- YouTube tutorial import, evidence fetch, lesson compilation, inline playback, and tutorial-mode guidance in the Mac app

Still not fully proven:

- one real production Google sign-in loop
- one real production Polar purchase + webhook + restore loop
- one real Sparkle update flow against a published release
- full end-to-end verification of the YouTube tutorial flow against real extractor output and repeated real-world use

## Get started with Claude Code

The fastest way to get this running is with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Once you get Claude running, paste this:

```
Hi Claude.

Clone https://github.com/farzaa/clicky.git into my current directory.

Then read the CLAUDE.md. I want to get Clicky running locally on my Mac.

Help me set up everything — the Cloudflare Worker with my own API keys, the proxy URLs, and getting it building in Xcode. Walk me through it.
```

That's it. It'll clone the repo, read the docs, and walk you through the whole setup. Once you're running you can just keep talking to it — build features, fix bugs, whatever. Go crazy.

## Manual setup

If you want to do it yourself, here's the deal.

### Prerequisites

- macOS 14.2+ (for ScreenCaptureKit)
- Xcode 15+
- Node.js 18+ (for the Cloudflare Worker)
- A [Cloudflare](https://cloudflare.com) account (free tier works)
- API keys for: [Anthropic](https://console.anthropic.com), [AssemblyAI](https://www.assemblyai.com), [ElevenLabs](https://elevenlabs.io)

### 1. Set up the Cloudflare Worker

The Worker is a tiny proxy that holds your API keys. The app talks to the Worker, the Worker talks to the APIs. This way your keys never ship in the app binary.

```bash
cd worker
npm install
```

Now add your secrets. Wrangler will prompt you to paste each one:

```bash
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put ASSEMBLYAI_API_KEY
npx wrangler secret put ELEVENLABS_API_KEY
```

For the ElevenLabs voice ID, open `wrangler.toml` and set it there (it's not sensitive):

```toml
[vars]
ELEVENLABS_VOICE_ID = "your-voice-id-here"
```

Deploy it:

```bash
npx wrangler deploy
```

It'll give you a URL like `https://your-worker-name.your-subdomain.workers.dev`. Copy that.

### 2. Run the Worker locally (for development)

If you want to test changes to the Worker without deploying:

```bash
cd worker
npx wrangler dev
```

This starts a local server (usually `http://localhost:8787`) that behaves exactly like the deployed Worker. You'll need to create a `.dev.vars` file in the `worker/` directory with your keys:

```
ANTHROPIC_API_KEY=sk-ant-...
ASSEMBLYAI_API_KEY=...
ELEVENLABS_API_KEY=...
ELEVENLABS_VOICE_ID=...
```

Then update the proxy URLs in the Swift code to point to `http://localhost:8787` instead of the deployed Worker URL while developing. Grep for `clicky-proxy` to find them all.

### 3. Update the proxy URLs in the app

The app has the Worker URL hardcoded in a few places. Search for `your-worker-name.your-subdomain.workers.dev` and replace it with your Worker URL:

```bash
grep -r "clicky-proxy" leanring-buddy/
```

You'll find it in:
- `CompanionManager.swift` — Claude chat + ElevenLabs TTS
- `AssemblyAIStreamingTranscriptionProvider.swift` — AssemblyAI token endpoint

### 4. Open in Xcode and run

```bash
open leanring-buddy.xcodeproj
```

In Xcode:
1. Select the `leanring-buddy` scheme (yes, the typo is intentional, long story)
2. Set your signing team under Signing & Capabilities
3. Hit **Cmd + R** to build and run

The app will appear in your menu bar (not the dock). Click the icon to open the panel, grant the permissions it asks for, and you're good.

### Permissions the app needs

- **Microphone** — for push-to-talk voice capture
- **Accessibility** — for the global keyboard shortcut (Control + Option)
- **Screen Recording** — for taking screenshots when you use the hotkey
- **Screen Content** — for ScreenCaptureKit access

## Architecture

If you want the full technical breakdown, read `CLAUDE.md`. But here's the short version:

**Menu bar app** with a floating companion shell, a custom Studio window, and a full-screen transparent cursor overlay. Push-to-talk captures audio, captures screen context plus cursor/focus context, routes the turn through a provider-agnostic assistant contract, and plays the response through local speech. `Claude`, `Codex`, and `OpenClaw` all plug into that shared turn model. Replies can embed `[POINT:x,y:label:screenN]` tags so the cursor can fly to specific UI elements across multiple monitors.

The repo also contains:

- `worker/` for the AI-provider secret proxy
- `backend/` for auth, billing, entitlements, launch trial state, website companion APIs, and tutorial extraction proxying
- `web/` for the marketing site plus the website companion layer
- `plugins/openclaw-clicky-shell/` for the OpenClaw shell integration

## Project structure

```
leanring-buddy/          # Swift source (yes, the typo stays)
  CompanionManager.swift    # Central state machine
  CompanionPanelView.swift  # Menu bar panel UI
  CompanionStudioNextView.swift # Current Studio window root
  ClickyAssistant*.swift    # Provider-agnostic assistant contract
  ClaudeAssistantProvider.swift # Claude adapter
  CodexAssistantProvider.swift  # Codex adapter
  OpenClawAssistantProvider.swift # OpenClaw adapter
  OverlayWindow.swift       # Blue cursor overlay
  AssemblyAI*.swift         # Real-time transcription
  Tutorial*.swift           # Tutorial import and playback models/clients
  BuddyDictation*.swift     # Push-to-talk pipeline
worker/                  # Cloudflare Worker proxy
  src/index.ts              # Claude / TTS / transcription secret proxy
backend/                 # Auth, billing, entitlements, web companion, tutorials
web/                     # Marketing site + web companion layer
plugins/openclaw-clicky-shell/ # OpenClaw shell plugin scaffold
```

## Contributing

PRs welcome. If you're using Claude Code, it already knows the codebase — just tell it what you want to build and point it at `CLAUDE.md`.

Got feedback? DM me on X [@farzatv](https://x.com/farzatv).
