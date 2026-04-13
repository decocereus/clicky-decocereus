# Clicky Website Companion PRD

Status: partially implemented product spec

Implementation note:

- the backend session, event, message, transcribe, and end routes exist
- the website companion UI, per-visitor session model, curated section context, target registry, and opt-in voice path exist
- the current browser flow uses a generated site-layout reference image as visual context rather than unrestricted live DOM or screen-share access
- the main remaining work is verification, tuning, and product polish rather than first-pass scaffolding

## Problem Statement

The current Clicky marketing site explains the product through strong visual
storytelling, but it still relies on the visitor inferring what Clicky feels
like from screenshots, motion, and copy.

That creates a gap:

- Clicky is most compelling when it feels alive, aware, and helpful.
- Static sections can explain capabilities, but they cannot fully demonstrate
  the product's conversational guidance loop.
- Video demos would help, but they are still linear and generic.
- The product promise is personal guidance, so the website should feel personal
  too.

We want the site itself to become the first Clicky experience by embedding a
live Clicky companion that talks with each visitor through a dedicated OpenClaw
session. The experience must preserve the current landing page design and
scroll choreography. The companion is additive, not a redesign.

## Solution

Add a persistent, context-aware Clicky companion layer to the existing landing
page.

Each visitor gets a separate website companion session backed by the production
OpenClaw agent. As the visitor moves through the current landing page, the
companion receives structured page context such as current section, dwell time,
visited sections, and CTA interactions. The companion can then:

- offer short, timely nudges
- answer questions in a chat panel
- explain the section the visitor is currently viewing
- highlight or point at important page elements
- optionally speak after the visitor explicitly enables voice

The experience should feel like "Clicky is guiding me through Clicky" rather
than "a chatbot widget was pasted on top of the site."

### Product principles

- Preserve the existing site: no landing page redesign, only additive layers.
- Start ambient, not intrusive: the companion should feel present before it
  feels talkative.
- One visitor, one session: every visitor gets an isolated OpenClaw thread.
- Structured awareness only: the agent should receive curated page context, not
  unbounded DOM access.
- Opt-in voice: do not autoplay narration on arrival.
- Assist conversion, do not pressure conversion: the companion should help the
  user understand, evaluate, and download.
- Keep OpenClaw as the upstream agent identity: Clicky owns the shell
  experience, not the underlying agent identity.

### Visitor experience states

1. Ambient presence
   A small Clicky companion is visible on the site, consistent with the current
   aesthetic. It appears as part of the experience, not as a generic support
   bubble.

2. Contextual invitation
   As the visitor settles into meaningful sections, Clicky can offer a short
   prompt such as "Want me to explain what Clicky is doing here?" These prompts
   should be sparse and dismissible.

3. Active conversation
   When the visitor opens the companion, Clicky responds conversationally,
   aware of the current section and prior browsing path.

4. Guided page interaction
   Clicky can highlight, pulse, or gently point to relevant page elements and
   optionally scroll the visitor to the next relevant section when asked.

5. Optional voice mode
   After explicit visitor interaction, Clicky can speak short responses in the
   browser. Voice is a second-phase enhancement, not the initial default.

### Core feature set for the first shippable version

- Persistent companion presence on desktop and mobile-safe layouts
- Separate OpenClaw-backed session per visitor
- Context-aware text chat
- Context-aware proactive nudges with strict frequency limits
- Structured highlight and point-to-element actions
- Conversation continuity across page sections during a single visit
- Session resume for a returning visitor within a limited time window
- Analytics for engagement, assistance, and conversion impact

### Non-goals for the first version

- Replacing the current landing page structure or visual direction
- Full browser automation or arbitrary agent tool execution
- Letting the agent inspect the raw DOM freely
- Autoplay voice on page load
- Turning the marketing site into a general-purpose customer support desk
- Multi-agent selection on the website
- Logged-in website requirement before using the companion

## User Stories

1. As a first-time visitor, I want to immediately notice that Clicky is alive
   on the site, so that the product feels different from a normal SaaS landing
   page.
2. As a first-time visitor, I want the site to keep its current visual design,
   so that the companion feels integrated rather than tacked on.
3. As a curious visitor, I want Clicky to explain the section I am currently
   reading, so that I do not need to guess what a screenshot or headline means.
4. As a skeptical visitor, I want to ask direct questions about what Clicky can
   and cannot do, so that I can evaluate whether the product is real and useful.
5. As a skeptical visitor, I want honest tradeoff answers, so that the site
   feels credible instead of overhyped.
6. As a visitor browsing multiple sections, I want Clicky to remember what I
   already saw, so that the conversation builds instead of repeating itself.
7. As a visitor on the pricing section, I want Clicky to explain what is
   included and who the product is for, so that I can decide whether to
   download.
8. As a visitor hovering or focusing on a CTA, I want Clicky to answer the
   likely decision-making question for that moment, so that the final step feels
   easier.
9. As a visitor who ignores the companion, I want the site to remain usable and
   uncluttered, so that the companion never blocks the normal browsing path.
10. As a visitor who dismisses proactive help, I want Clicky to back off, so
    that the experience does not become annoying.
11. As a visitor who engages, I want each conversation to feel like my own
    thread, so that Clicky can personalize the guidance to my journey.
12. As a returning visitor in the same browser, I want Clicky to remember a
    recent conversation for a short period, so that I can continue where I left
    off without long-term creepiness.
13. As a privacy-conscious visitor, I want the site to use a minimal anonymous
    session model, so that I do not need to create an account just to try the
    experience.
14. As a mobile visitor, I want a compact companion interaction model, so that
    the site still feels polished on a smaller screen.
15. As a visitor who prefers voice, I want to explicitly enable spoken replies,
    so that I can opt into a richer demo when I choose.
16. As a visitor who prefers quiet browsing, I want the site to stay text-first
    until I opt into voice, so that the experience respects browser and user
    expectations.
17. As a marketing operator, I want to author approved claims and section
    summaries, so that the agent speaks from a trusted source of truth.
18. As a marketing operator, I want to tune proactive nudges per section, so
    that the companion increases engagement without overwhelming visitors.
19. As a product owner, I want the companion to reinforce the Clicky shell
    identity, so that the website demonstrates the product thesis instead of
    hiding it.
20. As a product owner, I want one production OpenClaw agent to power the site,
    so that the experience stays aligned with the real product behavior.
21. As an engineer, I want each visitor session isolated, so that concurrent
    visitors cannot bleed context into one another.
22. As an engineer, I want the agent to operate on structured page context, so
    that the site remains safe, deterministic, and easier to evolve.
23. As an engineer, I want the website companion to reuse the Clicky shell
    mental model, so that desktop and web feel like parts of the same product.
24. As an engineer, I want the companion architecture to support future voice
    and richer pointing, so that phase one does not block the fuller vision.
25. As an analyst, I want to measure whether assisted visitors convert better
    than unassisted visitors, so that we can prove whether the companion is
    worth keeping.
26. As an analyst, I want to know which sections trigger the most questions, so
    that the site copy and agent prompts can improve together.
27. As a support operator, I want clear guardrails around what the agent may
    claim, so that the website does not invent pricing, roadmap promises, or
    unsupported capabilities.
28. As a future signed-in user, I want the companion session to optionally link
    to my authenticated state later, so that website exploration and product
    onboarding can connect when we are ready.

## Implementation Decisions

- The website companion is an additive overlay and interaction layer on top of
  the current landing page. Existing section layout, motion language, and art
  direction remain intact.
- The first production experience should be text-first with optional structured
  highlight actions. Voice is planned but should be explicitly opt-in.
- Browser voice playback should only activate after a user gesture so the
  product stays aligned with autoplay restrictions and visitor expectations.
- Each visitor receives a dedicated website companion session and a dedicated
  OpenClaw thread for that session.
- Session identity should be anonymous by default and stored in browser-local
  state plus a backend-recognized visitor identifier.
- The website companion should use curated section metadata rather than raw DOM
  scraping. The agent should know the section the visitor is on, the approved
  claims for that section, allowed highlight targets, and recent conversation
  summary.
- Proactive behavior should be rate-limited and event-driven. The agent should
  not generate a new turn for every scroll event.
- The website companion should share the Clicky shell thesis already used by the
  desktop app: OpenClaw remains the agent, Clicky remains the shell/presence
  layer.
- The website companion should preserve upstream OpenClaw identity while allowing
  Clicky-specific presentation inside the website shell.
- The first version should route browser requests through Clicky's backend
  instead of exposing the production OpenClaw Gateway directly to the browser.
- The backend should own session creation, throttling, analytics, prompt
  assembly, and OpenClaw request brokering.
- The agent response contract should be structured. Responses may include text,
  suggested replies, highlight/point actions, and optional voice instructions,
  but should not emit arbitrary code or DOM commands.
- The landing page sections should each define a content bundle containing
  approved claims, section intent, CTA targets, and companion guidance goals.
- The companion should know when to stay quiet. Dismissal, inactivity, and user
  focus on manual reading should all suppress unnecessary proactive behavior.
- Analytics should distinguish between passive page visits, assisted visits,
  engaged conversations, CTA-assisted visits, and downloaded visits.

## Testing Decisions

- Good tests should validate external behavior, not internal animation or prompt
  implementation details.
- The most important tests should cover:
  - visitor session creation and isolation
  - section-context delivery to the backend
  - rate-limited proactive nudge behavior
  - structured response handling in the browser
  - allowed highlight-target enforcement
  - graceful degradation when OpenClaw or network calls fail
- The product should be tested across desktop and mobile layouts to ensure the
  additive companion does not break the existing landing page experience.
- The backend should use contract tests for session bootstrap, event ingestion,
  and message streaming behavior.
- Prompt and policy coverage should use fixture-style tests against structured
  inputs and outputs instead of brittle exact-string assertions.
- There is little existing automated test prior art in the current `web/`
  surface, so this feature should establish new behavior-first coverage rather
  than mimic a large existing test suite.
- Manual product QA should explicitly verify:
  - the current landing page still feels unchanged without engagement
  - proactive nudges remain sparse
  - each browser session stays isolated
  - pricing answers remain accurate
  - the companion never blocks or obscures critical CTAs

## Out of Scope

- Rewriting the current landing page visual system
- Desktop app implementation changes unrelated to shared shell concepts
- Arbitrary browsing, form filling, or external tool execution by the website
  companion
- Multi-page docs/support chatbot behavior
- Full authenticated account linking for anonymous website visitors at launch
- Persistent long-term memory across devices for anonymous visitors
- A general customer support workflow with ticketing or CRM integrations
- A broad website redesign driven by the companion launch

## Further Notes

### Recommended rollout

1. Launch text-first companion with curated section context and chat.
2. Add structured highlight and point-to-element actions.
3. Add opt-in browser voice after the base experience is proven.

### Guardrails that should be explicit in product and prompt design

- Do not claim unsupported integrations, pricing, or roadmap promises.
- Do not interrupt every section with narration.
- Do not hide or compete with the site's existing storytelling.
- Do not let the agent treat the landing page like a generic support queue.
- Do not give the agent unrestricted access to the page structure.

### Success metrics

- Companion open rate
- Conversation start rate
- Assisted visitor to download conversion
- Pricing section assist rate
- Average sections visited before download
- Dismissal rate for proactive nudges
- Return visitor re-engagement rate
- Agent response latency and failure rate

### Working assumption for this PRD

The production website uses a single owner-controlled OpenClaw agent end to end.
This removes marketplace-style uncertainty and allows the product and
architecture to assume full control over prompt policy, session model, and
runtime behavior.
