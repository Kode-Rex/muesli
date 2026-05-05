# Chat UX Research for Muesli

Date: 2026-05-04

## TL;DR

- **Scope clarity is the #1 UX job.** Users must always know whether they are asking one talk or the whole conference. Every app that gets this wrong (early Granola per-meeting chat) produces trust failures when the answer is narrower than expected.
- **Granola's hover-to-preview citation is the gold standard for transcript apps.** Inline superscript numbers + a popover that shows the quoted passage + a jump-to-source link achieves both skimmability and verifiability without leaving the chat surface. ([granola.ai/blog](https://www.granola.ai/blog/product-teams-using-ai-notetaker-transcripts-to-revisit-decisions))
- **The typewriter/streaming effect must be gated behind Reduce Motion.** Apple's App Store accessibility evaluation criteria explicitly flags multi-step character-by-character animations as a Reduce Motion trigger; disabling the animation should fall back to instant text reveal. ([developer.apple.com](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/))
- **Scope should be declared before the first message, not discovered after a bad answer.** Notion AI's context control appears in the input bar itself as a filter pill; users pick scope before typing, not after. ([notion.com](https://www.notion.com/help/guides/get-answers-about-content-faster-with-q-and-a))
- **VoiceOver on iOS requires explicit `UIAccessibility.post(notification: .announcement)` calls for streamed content** — otherwise screen reader users hear nothing until the full response finishes, which can be 10-20 seconds. ([medium.com/@david-auerbach](https://medium.com/@david-auerbach/ios-accessibility-guidelines-best-practices-for-2025-6ed0d256200e))

---

## Pattern Catalog

### Granola Chat

**What they do:**
- Chat is a top-level navigation tab, not buried inside a single meeting. ([granola.ai/chat](https://www.granola.ai/chat))
- Granola 2.0: inline citations with a hover popover showing the verbatim transcript passage + a jump-to-source link. ([granola.ai/blog/two-dot-zero](https://www.granola.ai/blog/two-dot-zero))
- Two scope tiers: per-meeting ("Ask Granola") and per-folder ("Chat with Folders"). Scope is declared at the entry point — the Slack integration posts summaries with a "Chat with this meeting" button. ([shapeof.ai/patterns/citations](https://www.shapeof.ai/patterns/citations))
- `/` shortcut surfaces "Recipes" — expert-written saved prompts — reducing cold-start friction.

**Steal:** hover/tap citation popover; two-tier scope; Recipes.

**Avoid:** Early per-meeting chat had no persistent history — answers evaporated when you left the note. ([tldv.io](https://tldv.io/blog/granola-review/)) Muesli must persist threads.

---

### Notion AI Q&A

**What they do:**
- Entry point: sparkle icon fixed in the bottom-right corner, always reachable. ([notion.com/help/guides](https://www.notion.com/help/guides/get-answers-about-content-faster-with-q-and-a))
- Input bar has an explicit context filter: `@page-name` narrows to a page; blank queries the whole workspace. The model is never left guessing scope.
- History stores last 50 conversations, accessible via three-dot menu → "View History" with search. ([eesel.ai](https://www.eesel.ai/blog/notion-ai-chatbot))
- Known limitation: "current page" isn't auto-detected — users must @mention it manually. ([notion.com/help](https://www.notion.com/help/notion-ai-faqs))

**Steal:** scope filter in the input bar; persistent searchable history.

**Avoid:** The current-page detection gap. Muesli must auto-inject the active talk's note when the sheet opens from a talk detail view.

---

### Perplexity

**What they do:**
- Numbered inline superscript citations ([1], [2]) appear inside the answer prose at the sentence level. ([shapeof.ai/patterns/citations](https://www.shapeof.ai/patterns/citations))
- Tapping a superscript on iOS opens an in-app source card with site name, favicon, publication date, and author. A swipe or secondary action reveals the original URL in an in-app browser.
- A row of 3-5 follow-up suggestion chips appears below each answer, enabling threading without requiring users to free-type follow-ups.
- Answers stream with a visible cursor; the source list loads progressively as results arrive.

**Steal:** numbered superscript inline + tap-to-expand source card on mobile; follow-up suggestion chips beneath each answer.

**Avoid:** Web-search flavored "Sources" panel with favicons is redundant for a closed corpus like Muesli's transcript data. Simplify to talk title + timestamp range only.

---

### Otter.ai Chat

**What they do:**
- Three scoped modes: real-time during a live meeting, per-meeting after the fact, and cross-all-meetings. Each has a distinct entry point. ([otter.ai/blog/otter-ai-chat](https://otter.ai/blog/otter-ai-chat-ai-powered-meeting-assistant))
- Per-meeting chat is a collapsible right-side panel within the transcript view — not a modal. Collapsing preserves the transcript reading experience.
- Cross-meeting chat is a standalone top-level nav route.

**Steal:** collapsible side-panel keeping the transcript visible; separate nav route for conference-wide chat (especially good on iPad).

**Avoid:** Live meeting mode — Muesli ingests recordings after the fact; skip that entry point.

---

### Read.ai Search Copilot

**What they do:**
- "Search Copilot" is Read.ai's cross-meeting chat, positioned as a search replacement rather than a conversation tool. ([zapier.com/blog/read-ai](https://zapier.com/blog/read-ai/))
- Responses link to "exact meeting moments" — deep links into the transcript at the precise timestamp where the relevant content appears.
- The scope is global by default (all meetings); there is no visible toggle to narrow to one meeting within the same interface.
- Answers arrive quickly ("in seconds"), suggesting optimistic streaming or fast chunked response delivery.

**Steal:** deep timestamp-link citations that jump to the exact moment in the transcript, not just the meeting.

**Avoid:** Global-only scope is a UX failure when users want to interrogate one talk's Q&A session. Muesli must support both scopes.

---

### Mem 2.0 Chat

**What they do:**
- Chat lives in a resizable side panel that opens while viewing or editing a note — the note and the chat are simultaneously visible. ([get.mem.ai/blog/mem-2-0-alpha-testing-guide](https://get.mem.ai/blog/mem-2-0-alpha-testing-guide))
- The panel has "complete knowledge of all your notes" even when a specific note is open; users use `@note-name` or `#collection` to narrow scope explicitly.
- Inline citations use a **grey dotted underline** on the cited span within the answer, tapping which shows the source. This is subtler than numbered superscripts and integrates into prose flow.
- Users can "save a chat message as a note" — turning an AI answer directly into first-class content.

**Steal:** grey dotted underline citation style for a less cluttered citation aesthetic; "save this answer as a note" action per AI response.

**Avoid:** The `@note` scope mechanism requires users to know note names — fragile for conference apps where talk titles may be long or similar. Use a scope picker UI instead.

---

### GitHub Copilot Chat / Cursor

**What they do:**
- Copilot uses `@workspace`, `@file`, `@symbol` context participants — typed in the input itself — to scope the search. Each context item appears as a chip in the input bar before submission. ([code.visualstudio.com/docs/copilot](https://code.visualstudio.com/docs/copilot/chat/copilot-chat-context))
- Cursor renders code references as inline chips inside the response; clicking a chip jumps to the file + line number in the editor without leaving the chat. ([cursor.com/blog/cursor-3](https://cursor.com/blog/cursor-3))
- Copilot's agentic memory stores citations tied to specific code locations and surfaces them on hover.

**Steal:** context chips in the input bar showing what scope is active before the user sends; inline reference chips in responses that open the source location inline.

**Avoid:** `@symbol` syntax is for developers; a conference audience needs visual scope selectors, not typed commands.

---

### ChatGPT with Projects / File Upload

**What they do:**
- Files attached to a conversation appear as pill-shaped chips above the input bar, with the filename and a dismiss `×`. The chip is always visible so users know what context is loaded. ([help.openai.com](https://help.openai.com/en/articles/10169521-using-projects-in-chatgpt))
- Projects persist files and instructions across sessions; a sidebar icon indicates "shared" project state.
- Each new conversation within a Project inherits the attached files; scope is defined at the Project level, not per-thread.

**Steal:** persistent context pill chip above the input bar showing what is in scope — essential for Muesli's "1 talk" vs "all talks" disambiguation.

**Avoid:** Projects-as-containers is overengineered for a conference app where the unit of context is obvious (one talk, or the conference).

---

## Conventions Worth Adopting

- **Scope chip above the input bar.** Persistent pill ("WWDC25 — SwiftUI talk" / "All WWDC25 Talks (14)") — tapping it opens a scope picker. Users always know what's being searched. ([help.openai.com](https://help.openai.com/en/articles/10169521-using-projects-in-chatgpt), [notion.com](https://www.notion.com/help/guides/get-answers-about-content-faster-with-q-and-a))

- **Auto-inject scope from entry point.** Tapping "Ask AI" inside a talk detail → scope = that talk. Opening from the conference root → scope = all talks. Never require manual selection.

- **Inline superscript citations + tap-to-popover.** Tapping a numbered reference shows a popover with the verbatim transcript sentence, talk title, and a "Jump to transcript" link. ([granola.ai](https://www.granola.ai/blog/product-teams-using-ai-notetaker-transcripts-to-revisit-decisions), [shapeof.ai](https://www.shapeof.ai/patterns/citations))

- **Deep timestamp-link citations.** "Jump to transcript" opens the transcript at the exact timestamp, not the talk's top. ([zapier.com/blog/read-ai](https://zapier.com/blog/read-ai/))

- **Persistent thread history per scope.** Single-talk and conference threads stored separately, never evicted on close. ([eesel.ai](https://www.eesel.ai/blog/notion-ai-chatbot))

- **Empty-state Recipes.** Pre-baked prompts ("Summarize key takeaways," "List action items," "Q&A questions") surface as tappable chips when the thread is empty. ([granola.ai/updates](https://www.granola.ai/updates))

- **Follow-up chips below each response.** 2-3 model-generated follow-up questions; dismissed once the user starts typing. ([shapeof.ai](https://www.shapeof.ai/patterns/citations))

- **Respect Reduce Motion.** `UIAccessibility.isReduceMotionEnabled == true` → reveal full response atomically, no typewriter animation. ([developer.apple.com](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/))

- **VoiceOver sentence-boundary announcements.** Post `UIAccessibility.post(notification: .announcement)` at sentence ends during streaming — not per word. ([medium.com/@david-auerbach](https://medium.com/@david-auerbach/ios-accessibility-guidelines-best-practices-for-2025-6ed0d256200e))

- **Full-screen cover for conference-wide; resizable sheet for single-talk.** Single-talk chat as a `.medium`→`.large` detent sheet keeps transcript partially visible; conference-wide chat needs full focus. ([developer.apple.com/design/human-interface-guidelines/sheets](https://developer.apple.com/design/human-interface-guidelines/sheets))

---

## Conventions Worth Breaking (Because Conference Notes ≠ General Chat)

- **No global floating chat button.** Notion's fixed sparkle works when all pages are equal. Muesli's context is hierarchical (conference → talk → note); chat entry must live at the right level, not float globally.

- **History is secondary, not a tab.** In ChatGPT/Perplexity, threads are the primary artifact. In Muesli, the talk and its notes are. Bury history behind a clock icon in the sheet header, not a nav tab.

- **No `@mention` syntax for scope.** `@workspace` works for developers. Conference attendees need a visual scope picker — a segmented control or bottom-sheet labeled "This Talk / All Talks."

- **No generic follow-up chips.** Perplexity's chips are web-search flavored. Muesli's should be transcript-specific: "What questions came up in Q&A?", "Did the speaker mention a GitHub repo?", "Summarize the demo."

- **No in-chat note editing (v1).** Mem's "save answer as note" adds complexity. Shipping "Copy answer" first is sufficient; in-chat editing is a follow-up.

- **No favicon/domain source cards.** Perplexity's source metadata is for open-web results. Muesli's sources are always internal — use talk title, speaker, and timestamp only.

---

## Citation Rendering Decision

**Recommendation: numbered inline superscripts + tap-to-expand popover showing the verbatim transcript snippet + a "Jump to transcript" deep link.**

**Rationale:**

1. Numbered superscripts (Perplexity pattern) are proven for sentence-level attribution and are readable inline without disrupting prose flow. ([shapeof.ai/patterns/citations](https://www.shapeof.ai/patterns/citations))

2. A hover/tap popover showing the verbatim quoted passage (Granola pattern) is the critical addition for a transcript app — users can verify the model's claim without leaving the chat. ([granola.ai](https://www.granola.ai/blog/product-teams-using-ai-notetaker-transcripts-to-revisit-decisions))

3. A "Jump to transcript" deep link (Read.ai pattern) handles users who want full context — they jump to the exact timestamp rather than reading a truncated popover. ([zapier.com/blog/read-ai](https://zapier.com/blog/read-ai/))

4. A source tray below the answer (listing cited talks with chips) gives users a scannable list of which talks were cited without requiring them to read every superscript.

**Rejected alternatives:**

- *Footnotes at bottom of answer only* — too far from the claim; breaks reading flow.
- *Grey dotted underline only (Mem style)* — subtle and clean but offers no structured popover; too easy to miss on iOS touch targets.
- *No citations* — unacceptable for a research/recall app; trust requires verifiability.

---

## Specific Recommendations for Muesli's Chat Sheet

1. **Two entry points, two presentations.** From a talk's detail view: open a large-detent sheet (resizable up to full-screen) with scope pre-set to that talk. From the conference list view or a conference detail header: open a full-screen cover scoped to all talks in that conference.

2. **Scope chip at the top of the input area.** A tappable pill reading "SwiftUI Essentials — WWDC25" (for single-talk) or "All WWDC25 Talks (14)" (for conference scope) sits above the text field. Tapping it opens a scope-change sheet allowing the user to switch without starting a new thread.

3. **Scope change mid-thread is allowed but visually flagged.** When the user switches scope mid-conversation, insert a system message separator: "Scope changed to All WWDC25 Talks — previous context still available above." This is cleaner than requiring a new thread for each scope.

4. **Empty-state suggestion chips.** When the thread is empty, show 3 pre-seeded prompt chips tailored to the scope: single-talk mode → "Summarize key takeaways", "List action items", "What questions came up in Q&A?"; conference mode → "Compare how speakers covered [topic]", "Which talks mentioned Swift 6?", "Who had the most audience questions?"

5. **Inline superscript citation numbers** in the answer text. Keep them small (SF Symbols `textformat.superscript` or manual baseline offset), rendered in the app's accent color.

6. **Citation popover on tap.** Tap a superscript number → a `popover` (or `.sheet(isPresented:)` on smaller phones) appears showing: talk title, speaker, timestamp range, and a verbatim 1-3 sentence quote. A "Go to transcript" button deep-links to the `TranscriptView` at that timestamp.

7. **Source tray below each AI response.** A horizontally scrollable row of source chips appears beneath each answer. Each chip shows talk title (truncated to ~20 chars) and is tappable to navigate to that talk. If only one source is cited, show a single chip inline rather than a scroll row.

8. **Follow-up chips.** After each response, render 2-3 follow-up suggestion chips generated by the model. Tapping one sends it as the next message. Dismiss them once the user has typed anything in the input field.

9. **Streaming with Reduce Motion respect.** Text streams word-by-word with a blinking cursor under normal settings. When `UIAccessibility.isReduceMotionEnabled == true`, reveal the full response atomically after a brief spinner. A stop button (square icon) is always visible during generation.

10. **VoiceOver chunked announcement.** Post `UIAccessibility.post(notification: .announcement, argument:)` at sentence boundaries during streaming — not per word. Label the response region `accessibilityLabel("AI Response")` with `UIAccessibilityTraitUpdatesFrequently`.

11. **Thread history per scope.** A clock icon in the sheet header opens a history list filtered to the current scope. Each thread shows date, first message truncated to 60 chars, and turn count. Tapping restores it.

12. **Input bar.** Full-width text field, placeholder "Ask about this talk…" or "Ask about WWDC25…". Send activates only when non-empty; Return sends, Shift+Return inserts newline.

13. **Error states.** Rate limit → inline dismissible banner. Content-too-long → "Too many transcripts — try narrowing to a day or track." Network → "Saved your question — will send when reconnected." Never clear the input field on error.

14. **AI vs user color coding.** User messages: right-aligned filled bubble. AI responses: left-aligned full-width prose with no bubble (Granola's "AI in gray, user in black" pattern). ([granola.ai/blog](https://www.granola.ai/blog/product-teams-using-ai-notetaker-transcripts-to-revisit-decisions))

15. **iPad layout.** On regular horizontal size class, render chat as a sidebar column (~340 pt) alongside the transcript view rather than a modal sheet, matching Otter.ai's collapsible side-panel pattern. ([otter.ai/blog](https://otter.ai/blog/otter-ai-chat-ai-powered-meeting-assistant))

---

## Sources

- [Granola Chat — AI that knows what you're working on](https://www.granola.ai/chat)
- [Granola Updates — Inline Citations, Agentic Chat, Recipes](https://www.granola.ai/updates)
- [Granola 2.0 — Inline Citations & Jump-to-Source](https://www.granola.ai/blog/two-dot-zero)
- [Granola — Product Teams Using Transcripts to Revisit Decisions](https://www.granola.ai/blog/product-teams-using-ai-notetaker-transcripts-to-revisit-decisions)
- [The Art of Invisible AI — Granola's 70% Retention (UX Planet)](https://uxplanet.org/the-art-of-invisible-ai-what-granolas-70-retention-teaches-us-about-product-design-2de5a2836d17)
- [Granola Review 2026 — BlueDot HQ](https://www.bluedothq.com/blog/granola-review)
- [Granola Honest Review — tl;dv](https://tldv.io/blog/granola-review/)
- [Granola Guide — Wonder Tools](https://wondertools.substack.com/p/granolaguide)
- [Notion — Get Answers Faster with Q&A](https://www.notion.com/help/guides/get-answers-about-content-faster-with-q-and-a)
- [Introducing Notion Q&A](https://www.notion.com/blog/introducing-q-and-a)
- [Notion AI FAQs](https://www.notion.com/help/notion-ai-faqs)
- [Notion AI Chatbot — eesel AI](https://www.eesel.ai/blog/notion-ai-chatbot)
- [Notion AI Q&A in a Knowledge Hub — eesel AI](https://www.eesel.ai/blog/notion-ai-qa-in-knowledge-hub)
- [AI UX Patterns: Citations — ShapeofAI.com](https://www.shapeof.ai/patterns/citations)
- [Perplexity Platform Guide — Unusual AI](https://www.unusual.ai/blog/perplexity-platform-guide-design-for-citation-forward-answers)
- [Perplexity Mobile App Complete Review 2025](https://toolkitbyai.com/perplexity-mobile-app-complete-review-2025/)
- [Otter AI Chat Overview](https://help.otter.ai/hc/en-us/articles/19682180167575-Otter-AI-Chat-Overview)
- [Otter AI Chat — AI-Powered Meeting Assistant](https://otter.ai/blog/otter-ai-chat-ai-powered-meeting-assistant)
- [Otter Notetaker Chat Q&A for Meetings](https://help.otter.ai/hc/en-us/articles/18063735333399-Otter-Notetaker-Chat-Q-A-for-meetings)
- [8 Ways to Use Read AI — Zapier](https://zapier.com/blog/read-ai/)
- [Read AI vs Otter AI vs Jamie — Jamie](https://www.meetjamie.ai/blog/read-ai-vs-otter-ai)
- [Mem 2.0 Alpha Testing Guide](https://get.mem.ai/blog/mem-2-0-alpha-testing-guide)
- [Introducing Mem 2.0](https://get.mem.ai/blog/introducing-mem-2-0)
- [ChatGPT Projects — OpenAI Help Center](https://help.openai.com/en/articles/10169521-using-projects-in-chatgpt)
- [File Uploads FAQ — OpenAI](https://help.openai.com/en/articles/8555545-file-uploads-faq)
- [Manage Context for AI — Cursor / VS Code Copilot](https://code.visualstudio.com/docs/copilot/chat/copilot-chat-context)
- [Meet the New Cursor](https://cursor.com/blog/cursor-3)
- [Explainable AI in Chat Interfaces — Nielsen Norman Group](https://www.nngroup.com/articles/explainable-ai/)
- [Apple HIG: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [Customize and Resize Sheets in UIKit — WWDC21](https://developer.apple.com/videos/play/wwdc2021/10063/)
- [Reduced Motion Evaluation Criteria — App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/)
- [Reduce Motion — Make iOS App Animations Accessible](https://medium.com/@amosgyamfi/reduce-motion-how-to-make-your-ios-app-animations-accessible-and-inclusive-92b9de1304fb)
- [iOS Accessibility Guidelines 2025](https://medium.com/@david-auerbach/ios-accessibility-guidelines-best-practices-for-2025-6ed0d256200e)
- [Where Should AI Sit in Your UI — UX Collective](https://uxdesign.cc/where-should-ai-sit-in-your-ui-1710a258390e)
- [Bottom Sheets vs Fullscreen Modals — Design for Native](https://designfornative.com/bottom-sheets-vs-fullscreen-modals/)
