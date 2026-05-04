# Granola Gap Analysis for Muesli (Conference Edition)

Date: 2026-05-04

## TL;DR

- Granola's product wedge is the **"augmented notes"** model: user shorthand stays as-is (in black), and AI fills in context from the transcript (in gray) after the meeting ends. Muesli already has the raw ingredients (user notes + transcript + AI summary) but treats summary as a separate blob, not as inline augmentation of the user's own notes.
- Granola is **online-first and desktop-first** ([Granola requires internet for AI features](https://www.craftnoteapp.com/blog/best-ai-notetakers-in-person-meetings-2026); custom templates are macOS/Windows only per [BluedotHQ review](https://www.bluedothq.com/blog/granola-review)). For conferences with bad wifi and a phone-in-pocket workflow, Muesli's iOS-native + on-device hybrid transcription stack is genuinely a differentiator, not a gap.
- Biggest real gaps: **templates**, **chat-with-note**, **action-item extraction**, **export/share**, and **organization** (folders, search across notes). Muesli has a flat note list and one fixed summary shape.
- Already in good shape: capture (mic + duration + waveform), hybrid on-device/Deepgram transcription with graceful fallback, image attachments (slides), AI titles, editable summaries, SwiftData persistence with in-memory fallback.
- Conference twist: photos of slides matter more than calendar sync; talks are unidirectional so speaker diarization is low-value; the user is in audience mode, not host mode, which changes the entire "follow-up email" framing.

## Granola Feature Inventory

### Capture
- **Bot-free local capture** of mic + system audio on macOS/Windows desktop ([granola.ai/security](https://www.granola.ai/security), [Zack Proser review](https://zackproser.com/blog/granola-ai-review)). Not visible to other meeting participants.
- **Works with any video platform** (Zoom, Meet, Teams, Webex) by tapping into system audio rather than joining as a bot ([How to use Granola with Zoom](https://www.granola.ai/blog/how-to-use-granola-with-zoom)).
- **iOS app** (launched 2026) for in-person and phone-call capture, lock-screen widget for one-tap recording ([TechCrunch](https://techcrunch.com/2026/03/25/granola-raises-125m-hits-1-5b-valuation-as-it-expands-from-meeting-notetaker-to-enterprise-ai-app/), [SpeakApp blog](https://speakapp.com/blog/granola-mobile-app)).
- Audio is **not stored** — only the transcript is retained; no playback ([tldv review](https://tldv.io/blog/granola-review/)).
- Live transcription during the meeting; AI augmentation runs **post-hoc** when the meeting ends ([docs](https://docs.granola.ai/help-center/taking-notes/transcription)).

### Note Structure & "Augmented Notes"
- Core insight: user types **shorthand notes** during the meeting; Granola merges them with the transcript afterward into polished notes ([BusinessWire launch](https://www.businesswire.com/news/home/20240522650474/en/)).
- User-typed text stays in **black**; AI-added expansion is in **gray**, visually distinguishing human vs. machine content.
- "Zoom In" feature shows the **exact transcript quote** an AI line is grounded in ([tldv review](https://tldv.io/blog/granola-review/)).
- Typos are auto-cleaned; "$10K" gets expanded to "Photography budget can go up to $10K" using transcript context.

### AI Features
- **Granola Chat**: ask questions of a single note or across folders ("What did the client say about budget?", "Draft a follow-up email") ([granola.ai/chat](https://www.granola.ai/chat), [Chat docs](https://docs.granola.ai/help-center/getting-more-from-your-notes/chatting-with-your-meetings)).
- **Action items / decisions / deadlines** auto-extracted from notes + transcript.
- **Follow-up email generation** in one click.
- **Recipes** (late 2025): reusable AI prompts as a "lens" over a meeting — e.g. extract objections, summarize for an exec, generate a blog post ([Wonder Tools](https://wondertools.substack.com/p/granolaguide)).
- **Cross-meeting / folder-level Q&A** to surface trends and recurring themes.

### Templates
- Built-in templates for 1:1, standup, customer discovery, user interview, sales pitch, etc. (homepage).
- **Custom templates** are user-creatable on macOS/Windows desktop only — **iOS cannot create or apply templates** ([BluedotHQ review](https://www.bluedothq.com/blog/granola-review)).
- Templates are shareable through team/shared folders.

### Organization
- **Folders** for grouping notes; query across a folder's transcripts.
- **Spaces** (rolling out 2026): team workspaces containing folders with granular access controls ([TechCrunch](https://techcrunch.com/2026/03/25/granola-raises-125m-hits-1-5b-valuation-as-it-expands-from-meeting-notetaker-to-enterprise-ai-app/)).
- **Calendar integration** with Google and Microsoft/Outlook auto-populates upcoming meetings; transcription auto-starts ([calendar docs](https://docs.granola.ai/help-center/getting-started/syncing-your-calendars)).
- Search across notes.

### Collaboration & Sharing
- **Copy as Markdown** to clipboard — primary export path ([sharing docs](https://docs.granola.ai/help-center/sharing/sharing-notes)).
- **Email draft** opens Gmail with note pre-filled.
- **Public share links** with viewer access by default.
- No native PDF/DOCX/JSON export; community has built unofficial Markdown/Obsidian exporters ([Joseph Thacker reverse-engineered](https://josephthacker.com/hacking/2025/05/08/reverse-engineering-granola-notes.html), [Granola-to-Obsidian plugin](https://github.com/dannymcc/Granola-to-Obsidian)).
- Friction widely reported: "Great Notes, Too Much Friction To Share" ([meetingnotes.com teardown](https://meetingnotes.com/blog/granola-ai-teardown)).

### Integrations
- Slack, Notion, HubSpot, Attio, Affinity, Zapier (8000+ apps), plus a **personal API** and **enterprise API** in 2026 ([TechCrunch](https://techcrunch.com/2026/03/25/granola-raises-125m-hits-1-5b-valuation-as-it-expands-from-meeting-notetaker-to-enterprise-ai-app/)).

### Pricing
- **Free (Basic)**: AI-enhanced notes, chat, shared folders, multi-language, but **last 30 days of history only** ([granola.ai/pricing](https://www.granola.ai/pricing), [alfred_ analysis](https://get-alfred.ai/blog/granola-pricing)).
- **Business**: $14/user/mo — unlimited history, advanced AI models, integrations, team controls.
- **Enterprise**: $35+/user/mo — SSO, governance, configurable retention 30 days–7 years, choice of data region.

### Platforms
- **macOS, Windows, iOS**. No Android, no web app for note-taking ([Granola homepage](https://www.granola.ai/)).
- iOS↔desktop sync is real-time.

### Privacy & Data
- AWS-hosted, multi-tenant; **not on-device, not single-tenant** ([security page](https://www.granola.ai/security)).
- TLS 1.3 in transit, AES-256 at rest, HSM key storage. SOC 2 Type 2, GDPR-aligned DPA.
- Audio is **not stored**; transcripts are. Users delete manually unless an enterprise retention policy applies.
- Enterprise can pick region (US-East, US-West, EU-Frankfurt, UK, Canada, AU).
- Hard offline gap: Granola broke during the Oct 2025 AWS outage and the founder publicly committed to making it work fully offline ([@cjpedregal on X](https://x.com/cjpedregal/status/1980322615815496107)).

## Muesli Current State

Inferred from the codebase at `/Users/travisfrisinger/Documents/projects/muesli/src/mobile/Muesli` and `/src/api`.

### Capture
- **Implemented**: `AudioRecordingManager.swift` for mic recording with duration; `WaveformView` and recent fixes to recording timer/animation (commit `aaf75b5`, `ab318cd`, `bb36cdf`).
- iOS-native, mic-only — no system audio (and no need for it on a phone in audience seats).
- Recording state, audio file path, and duration persist on the `Note` model.

### Note Structure
- `Models.swift` defines a single `Note` with: `title`, `content`, `userNotes`, `aiSummary`, `imagePaths[]`, `audioFilePath`, `transcriptionStatus`, `duration`, `conferenceName`, `sessionType`, `isArchived`.
- Recent commits (`c5af51a`, `1387981`, `2a5599e`) split `userNotes` away from `content` to fix conflicts with the transcript — the model is converging toward a Granola-style separation but not yet doing inline augmentation.
- No template concept. No structured sections. `sessionType` is a free-form string ("meeting" / "session" / "note").

### Transcription
- `HybridTranscriptionService` + `LocalTranscriptionService` + `TranscriptionService` — supports **on-device iOS Speech** with graceful fallback to **Deepgram** via the API backend (commits `92f3d4c`, `a01b4a9`).
- API exposes `transcription.js` and `summarization.js` routes.
- **This is a real edge over Granola** for the conference use case: bad wifi → falls back to on-device.

### AI / Summary
- `AISummaryService.swift` and `SimpleSummaryGenerator.swift` produce a single `aiSummary` string. Editable by default (`fc74f26`), rendered as Markdown (`47c6ca9`), generated from user notes when transcript is empty (`1cc4616`).
- No chat-with-note, no action items, no follow-up generation, no cross-note Q&A.

### Organization
- `MyNotesView`, `SimpleArchiveView`, `SearchBarView` exist. Archive flag on Note.
- No folders, no tags, no calendar import. `conferenceName` is a free-text field — the only conference-specific dimension and it isn't used as a grouping primitive in any view I can see.

### Sharing / Export
- No export code surfaced. No share sheet, no Markdown copy, no email draft, no PDF.

### Images
- Image attachments to notes are implemented (`ImagePicker`, `FullscreenImageViewer`, commits `b643178`, `b4fba99`). This is a conference-specific superpower: photos of slides.

### Persistence & Platform
- SwiftData with in-memory fallback. iOS only. No macOS, no companion web.
- API backend (Node + Express + Deepgram + Winston) is stateless and used as a transcription/summarization service, not a sync backend. **No cross-device sync.**

### Known Issues from Recent Commits
- Black-screen sheet bug fixed (`a52ec92`, `18e2a63`).
- Empty-transcript summary bug (`2a5599e`).
- Notes vs. content variable conflict (`1387981`).

These suggest the editor flow is still stabilizing.

## Gap Matrix

| Feature | Granola | Muesli | Priority | Notes |
|---|---|---|---|---|
| Mic capture | Yes | Yes | — | Done |
| System audio capture | Yes (desktop) | N/A | skip | Irrelevant on iOS for in-person talks |
| Bot-free meeting capture | Yes | N/A | skip | Conference talks aren't video calls |
| Hybrid on-device + cloud transcription | No (cloud-only) | **Yes** | — | Muesli advantage; protect it |
| Live transcript view | Yes | Partial (`TranscriptView.swift` exists) | P1 | Validate quality during talk |
| Augmented notes (user-shorthand → AI-expanded inline, with provenance) | Yes (signature feature) | No (separate `userNotes` and `aiSummary`) | **P0** | Closest thing to Granola's wedge |
| Quote-grounded "Zoom In" from AI line back to transcript | Yes | No | P1 | Trust feature — important for talks where misquoting a speaker is bad |
| Templates (per-session-type) | Yes | No | **P0** | Conference templates: keynote, workshop, panel, demo, hallway track |
| Custom user templates | Yes (desktop only) | No | P2 | After built-ins ship |
| Action items extraction | Yes | No | P1 | Reframed for conferences: "things to try / books / people to follow / questions to ask" |
| Chat-with-note (single note) | Yes | No | **P0** | Asking "what did the speaker say about X" is the natural conference Q&A |
| Cross-note / folder Q&A | Yes | No | P1 | "Across this conference, what came up about LLM evals?" — high value |
| Recipes (reusable AI prompts) | Yes | No | P2 | Nice once chat exists |
| Folders | Yes | No | **P0** | Group by conference is the obvious primitive |
| Tags | No (uses folders) | No | P1 | Track speaker, topic, day |
| Search across notes | Yes | Search bar exists, scope unclear | P1 | Verify it searches transcripts + summaries |
| Calendar integration | Yes | No | skip | Conference schedules aren't on Google Calendar; .ics import maybe later |
| Photo / slide attachments | No | **Yes** | — | Muesli advantage; protect and lean in |
| OCR on slide photos | No | No | **P0** | Killer conference feature — slide photo + transcript context |
| Export Markdown | Yes (clipboard) | No | **P0** | Lowest-effort sharing primitive |
| Email draft / Share sheet | Yes | No | P1 | Native iOS share sheet is one screen |
| Public share link | Yes | No | P2 | Needs a backend; defer |
| PDF export | No (community only) | No | P2 | |
| Slack / Notion / CRM integrations | Yes | No | skip for v1 | Not the audience for a conference app |
| Cross-device sync | Yes (iOS↔desktop) | No | P1 | iCloud/CloudKit is the cheap path |
| Offline-first | Partial | **Yes** (on-device path) | — | Muesli advantage |
| AI follow-up email | Yes | No | P2 | Conference framing: "email myself a recap" |
| AI titles | Yes (implied) | **Yes** (`b4fba99`) | — | Done |
| Speaker diarization | Yes ("Me"/"Them") | No | skip | Conference talks are mostly single-speaker |
| Multi-language transcription | Yes | iOS Speech supports it; unclear if surfaced | P2 | International conferences |
| Free tier with history cap | 30 days | N/A (local-only, unlimited) | — | Muesli advantage if positioned right |

## Conference-Specific Twists

Granola is built for the **back-to-back-meetings knowledge worker**. Muesli is for the **conference attendee**. Almost every assumption shifts:

1. **Audio is unidirectional.** A keynote is one speaker on a stage, mic'd through a PA. There's no "Me" vs. "Them" — it's "speaker" vs. "audience Q&A". Diarization is mostly wasted effort, but a simple "speaker / audience question" split during Q&A is high-value.
2. **No prior context with the speaker.** Granola assumes you know the person and have history. At a conference you're hearing someone for the first time. Augmented notes should pull in **public context** (who is this person, what have they written) more than personal history.
3. **Slide photos are the missing modality.** Conference slides carry 50% of the information density. Muesli already supports photo attachments — the obvious next step is OCR + binding photos to the timeline of the transcript so a slide appears next to the moment it was shown.
4. **Wifi at conferences is famously bad.** Granola's cloud dependency is a liability here; Muesli's on-device transcription path is the right call. Build the product around the assumption that the network is unreliable.
5. **No calendar integration is needed.** Conference schedules live in conference apps (Sched, Whova) or PDFs. A simple **import .ics** or "create session from clipboard" is enough; full Google Calendar sync is over-engineered.
6. **Sessions cluster by event, not by week.** The natural folder is "Conference X 2026". Day, track, and speaker are the useful sub-facets. This is different from Granola's flat folder-per-team model.
7. **The output is for the user themselves, not a team.** No Slack push, no CRM push, no follow-up email to the speaker. The output is: a personal recap, a tweet/blog draft, a list of "things to learn more about", and shareable markdown for a post.
8. **Q&A and audience questions are gold.** A separate "questions asked" section with timestamps would surface dialogue that almost never makes it into official recordings.
9. **Privacy is different.** You're recording a public talk (often allowed), not a confidential business meeting. The pressure for SOC 2 / enterprise governance is much lower; the pressure for "works on a plane / in a basement ballroom" is much higher.
10. **Single long session, not many short meetings.** A keynote is 45–60 minutes. A workshop is 3 hours. The transcript is longer, the user-notes are sparser, and chunking strategy for AI summarization differs.

## Recommended P0 Feature Set for v1

The minimum to credibly position Muesli as "Granola for conferences":

1. **Conferences as folders.** First-class `Conference` entity with name, dates, location. Notes belong to a conference. Replace the free-text `conferenceName` field.
2. **Session templates.** A small set: Keynote, Talk, Workshop, Panel, Hallway. Each has prompted sections (Speaker, Key claims, Demos shown, Things to try, Questions to research).
3. **Augmented notes view.** Render `userNotes` inline with AI expansions visually distinct (different weight or color), grounded in transcript spans. This is the Granola wedge applied to talks.
4. **Slide OCR + timeline binding.** When the user snaps a slide photo, OCR the text, and place the photo at the matching moment in the transcript. Slide text feeds into the AI summary.
5. **Chat with a note.** Ask the note questions ("what did she say about evals?"). Use existing summarization infra; route through Deepgram/cloud only when online.
6. **Action items, conference-flavored.** Auto-extract: "things to try", "books/papers mentioned", "people referenced", "tools demoed". Not "send follow-up email to Steve".
7. **Markdown export + native share sheet.** Copy-as-Markdown and iOS share sheet. Unblocks blogging, Obsidian, notes apps. One afternoon of work, huge utility.
8. **Cross-note search across a conference.** "What came up about RAG this week?" across all notes in a conference folder. Builds on chat-with-note.
9. **Reliable offline mode end-to-end.** Verify the full path (record → on-device transcribe → summarize-on-device-or-queue → AI-augment-when-online) works with no network. This is the unique selling point against Granola; make it a first-class promise.
10. **iCloud sync.** CloudKit-backed `Note` and conference data so a user with an iPhone + iPad doesn't lose work. Cheaper than building a sync backend.

## Open Questions

- **What does "augmented notes" rendering look like in SwiftUI?** Granola uses font color in a single editor. Muesli currently has separate `userNotes` and `aiSummary` fields. Does this become one rich text view with attributes, or two views with linked scroll? Product question, not just engineering.
- **Do we ship a summarization model on-device** (e.g. Apple Foundation Models / a small MLX model) or accept that summary requires network? The transcription stack has a hybrid path; the AI summary path doesn't yet.
- **What's the photo-to-transcript binding UI?** Inline thumbnails in the transcript? A separate slide reel synced by timestamp? A swipe between modes?
- **Pricing model.** Local-only with no server costs supports a one-time purchase or cheap subscription. Are we trying to compete on price (Granola $14/user/mo) or on "your data stays on your device"?
- **Audio retention.** Granola deletes audio. Muesli currently keeps it (`audioFilePath`). For conferences this is probably right (re-listen to a moment) but storage management needs UI.
- **Speaker identification.** Do we let the user tag the speaker once (name + bio pulled from a URL or the conference site)? This would be more useful than diarization.
- **How does a conference get into the app?** Manual creation, .ics import, Sched/Whova import, or scrape a conference website?
- **Is there a Mac companion app on the roadmap?** A user typing notes on a laptop during a talk is a common workflow. iOS-only may be a self-imposed limit.

## Sources

- [Granola homepage](https://www.granola.ai/)
- [Granola pricing](https://www.granola.ai/pricing)
- [Granola Chat](https://www.granola.ai/chat)
- [Granola security page](https://www.granola.ai/security)
- [Granola Help Center: Transcription](https://docs.granola.ai/help-center/taking-notes/transcription)
- [Granola Help Center: Calendar sync](https://docs.granola.ai/help-center/getting-started/syncing-your-calendars)
- [Granola Help Center: Sharing notes](https://docs.granola.ai/help-center/sharing/sharing-notes)
- [Granola Help Center: Chatting with your meetings](https://docs.granola.ai/help-center/getting-more-from-your-notes/chatting-with-your-meetings)
- [TechCrunch: Granola raises $125M, $1.5B valuation (Mar 2026)](https://techcrunch.com/2026/03/25/granola-raises-125m-hits-1-5b-valuation-as-it-expands-from-meeting-notetaker-to-enterprise-ai-app/)
- [TechCrunch: Granola debuts AI notepad (May 2024)](https://techcrunch.com/2024/05/22/granola-debuts-an-ai-notepad-for-meetings/)
- [BusinessWire: Granola launch](https://www.businesswire.com/news/home/20240522650474/en/)
- [tldv: Granola review 2026](https://tldv.io/blog/granola-review/)
- [BluedotHQ: In-Depth Granola Review 2026](https://www.bluedothq.com/blog/granola-review)
- [Wonder Tools: Granola guide](https://wondertools.substack.com/p/granolaguide)
- [Zack Proser: Granola review](https://zackproser.com/blog/granola-ai-review)
- [Zapier: What is Granola](https://zapier.com/blog/granola-ai/)
- [meetingnotes.com: Granola teardown — sharing friction](https://meetingnotes.com/blog/granola-ai-teardown)
- [SpeakApp: Granola Mobile App](https://speakapp.com/blog/granola-mobile-app)
- [Granola Zoom integration blog](https://www.granola.ai/blog/how-to-use-granola-with-zoom)
- [Granola free vs paid](https://www.granola.ai/blog/granola-free-vs-paid-features-each-plan)
- [alfred_: Granola pricing free plan history cap](https://get-alfred.ai/blog/granola-pricing)
- [CraftNote: Best AI notetakers for in-person meetings (offline-ready)](https://www.craftnoteapp.com/blog/best-ai-notetakers-in-person-meetings-2026)
- [@cjpedregal on X: AWS outage / offline commitment](https://x.com/cjpedregal/status/1980322615815496107)
- [Joseph Thacker: Reverse engineering Granola for Obsidian](https://josephthacker.com/hacking/2025/05/08/reverse-engineering-granola-notes.html)
- [dannymcc/Granola-to-Obsidian (GitHub)](https://github.com/dannymcc/Granola-to-Obsidian)
- [Circleback: Recording in-person meetings with Granola](https://circleback.ai/how-to/recording-in-person-meetings-with-granola-workarounds)
