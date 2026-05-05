# Capture Loop Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the six punch-list bugs from the capture-loop hardening spec — main-actor isolation, modelContext lifetime, transcription race, CORS default, log redaction — without touching code the AI pipeline rewrite will replace.

**Architecture:** Six independent fixes across four iOS files and two API files. Each fix is a small, surgical change with clear before/after. Where TDD applies cleanly (Jest on the API), use it; where the property is concurrency/timing rather than behavior, rely on Swift's strict-concurrency warnings plus runtime smoke checks.

**Tech Stack:** Swift / SwiftUI / SwiftData (iOS), Node.js / Express / Joi / Winston / Jest (API).

---

## File Structure

| File | Change | Why |
|---|---|---|
| `src/mobile/Muesli/AudioRecordingManager.swift` | Modify lines 383-410 | Replace `DispatchQueue.main.async` with `Task { @MainActor in }`; fix `audioRecorderEncodeErrorDidOccur` main-actor isolation |
| `src/mobile/Muesli/Views/SimpleMainView.swift` | Modify lines 198-228 | Replace `DispatchQueue.main.async` inside `Task {}` with `await MainActor.run` |
| `src/mobile/Muesli/Services/TranscriptionOrchestrator.swift` | Create | Long-lived service owning the `ModelContainer`, runs post-save transcription work; eliminates view-scoped `modelContext` lifetime risk |
| `src/mobile/Muesli/Views/NewNoteView.swift` | Modify line 502-506 | Hand off batch transcription to the orchestrator instead of spawning Task from the view |
| `src/mobile/Muesli/Views/SimpleNoteDetailView.swift` | Modify lines 343-426 | Add `@State` task-handle guard to prevent re-trigger race |
| `src/api/src/config/index.js` | Modify line 28 + add prod check | CORS required, no `'*'` in production |
| `src/api/src/utils/redactConfig.js` | Create | Pure utility: strips secret-shaped fields from any object |
| `src/api/src/utils/logger.js` | Modify (add formatter) | Apply `redactConfig` as a Winston formatter so future logs are protected |
| `src/api/tests/unit/redactConfig.test.js` | Create | Unit tests for redactor |
| `src/api/tests/unit/config.test.js` | Create | Tests CORS Joi schema rules |

---

### Task 1: Fix AudioRecordingManager delegate main-actor isolation

**Files:**
- Modify: `src/mobile/Muesli/AudioRecordingManager.swift:374-410`

The class is `@Observable`. Both delegate methods are called by AVFoundation off the main thread. `audioRecorderDidFinishRecording` already wraps in `DispatchQueue.main.async`; `audioRecorderEncodeErrorDidOccur` does not. Bring both in line and migrate to structured concurrency.

- [ ] **Step 1: Read the current state of both delegate methods**

Run:
```bash
grep -n "audioRecorderDidFinishRecording\|audioRecorderEncodeErrorDidOccur" src/mobile/Muesli/AudioRecordingManager.swift
```

Expected: two matches, around lines 374 and 397.

- [ ] **Step 2: Replace both delegate method bodies**

In `src/mobile/Muesli/AudioRecordingManager.swift`, replace lines 374-410 (the two delegate methods + closing brace of the class) with:

```swift
nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    if recorder.currentTime < 1.0 {
        AppLogger.shared.warning("Recording finished too quickly - possible audio session conflict or simulator limitation")
    }

    Task { @MainActor in
        if flag {
            AppLogger.shared.info("Recording finished successfully")
            self.state = .finished
        } else {
            AppLogger.shared.error("Recording failed to finish")
            self.state = .idle
            self.currentRecordingPath = nil
            self.recordingDuration = 0
            self.stopDurationTimer()
        }
    }
}

nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
    AppLogger.shared.error("Recording encode error", error: error)

    Task { @MainActor in
        self.state = .idle
        self.currentRecordingPath = nil
        self.recordingDuration = 0
        self.stopDurationTimer()

        do {
            try self.audioSession.setActive(false)
        } catch {
            AppLogger.shared.warning("Failed to deactivate audio session after encode error: \(error)")
        }
    }
}
}
```

The `nonisolated` annotation is required because `AVAudioRecorderDelegate` is not `MainActor`-isolated and Swift 6 strict concurrency requires the override to match.

- [ ] **Step 3: Build to verify no concurrency warnings**

Run:
```bash
./scripts/build.sh clean
```

Expected: clean build, no `actor-isolated property` warnings on `state`, `currentRecordingPath`, `recordingDuration`.

- [ ] **Step 4: Commit**

```bash
git add src/mobile/Muesli/AudioRecordingManager.swift
git commit -m "fix(ios): isolate AVAudioRecorder delegate state mutations to main actor

Both delegate methods now hop to MainActor via structured concurrency.
audioRecorderEncodeErrorDidOccur previously mutated @Observable state
on whatever thread AVFoundation called it on."
```

---

### Task 2: Complete the MainActor refactor in SimpleMainView

**Files:**
- Modify: `src/mobile/Muesli/Views/SimpleMainView.swift:198-228`

Holdovers from the `334818b` refactor — `DispatchQueue.main.async` blocks inside `Task {}`. Replace with `await MainActor.run` to match `NewNoteView.swift:527`.

- [ ] **Step 1: Replace the transcription Task body**

In `src/mobile/Muesli/Views/SimpleMainView.swift`, replace lines 197-229 with:

```swift
        // Process transcription with hybrid service
        Task {
            do {
                let transcript = try await HybridTranscriptionService.shared.transcribeAudioFile(url: audioURL)

                await MainActor.run {
                    note.content = transcript
                    note.transcriptionStatus = "completed"
                    note.title = SimpleSummaryGenerator.generateTitle(from: transcript)
                    note.aiSummary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: note.userNotes)

                    do {
                        try modelContext.save()
                        AppLogger.shared.info("Successfully transcribed note: \(note.title) (\(transcript.count) chars)")
                    } catch {
                        AppLogger.shared.dataError("Save Transcription", error: error)
                        note.transcriptionStatus = "failed"
                    }
                }
            } catch {
                await MainActor.run {
                    note.transcriptionStatus = "failed"
                    do {
                        try modelContext.save()
                    } catch {
                        AppLogger.shared.dataError("Update Failed Status", error: error)
                    }
                }
                AppLogger.shared.info("Transcription failed for note: \(note.title) - \(error.localizedDescription)")
            }
        }
    }
```

Note: removed `self.modelContext` references — inside `await MainActor.run`, `modelContext` from the enclosing struct's scope is captured directly.

- [ ] **Step 2: Build**

Run:
```bash
./scripts/build.sh
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add src/mobile/Muesli/Views/SimpleMainView.swift
git commit -m "refactor(ios): finish MainActor migration in SimpleMainView

Replace DispatchQueue.main.async inside Task with await MainActor.run
to match NewNoteView. Holdover from commit 334818b."
```

---

### Task 3: Guard against transcription re-trigger race

**Files:**
- Modify: `src/mobile/Muesli/Views/SimpleNoteDetailView.swift:343-427`

If the user closes and reopens the note sheet while transcription is in flight, `.onAppear` can fire twice and spawn parallel transcription tasks. Guard with a view-scoped `@State` task handle.

- [ ] **Step 1: Find the @State block in SimpleNoteDetailView**

Run:
```bash
grep -n "@State" src/mobile/Muesli/Views/SimpleNoteDetailView.swift | head -10
```

Note the line number of the first `@State` declaration to locate where to add the new state.

- [ ] **Step 2: Add the task-handle state property**

In `src/mobile/Muesli/Views/SimpleNoteDetailView.swift`, add the following `@State` declaration immediately after the last existing `@State` property in the view struct (before the `var body` declaration):

```swift
    @State private var transcriptionTask: Task<Void, Never>?
```

- [ ] **Step 3: Wrap the transcription work in the guarded task handle**

Replace the entire body of `checkAndTriggerPendingTranscription()` (lines 352-427) with:

```swift
    private func checkAndTriggerPendingTranscription() {
        guard transcriptionTask == nil else {
            AppLogger.shared.debug("Transcription already in flight - skipping re-trigger")
            return
        }
        guard note.content.isEmpty else {
            AppLogger.shared.debug("Note has content (\(note.content.count) chars), skipping transcription")
            return
        }
        guard note.transcriptionStatus == "pending" else {
            AppLogger.shared.debug("Note status is '\(note.transcriptionStatus)', not pending - skipping")
            return
        }
        guard let audioPath = note.audioFilePath else {
            AppLogger.shared.warning("No audio file path in note - cannot transcribe")
            return
        }

        AppLogger.shared.info("🎯 Note opened with pending transcription - triggering now for '\(note.title)'")

        note.transcriptionStatus = "processing"
        do {
            try modelContext.save()
            AppLogger.shared.info("✅ Updated note status to 'processing'")
        } catch {
            AppLogger.shared.error("❌ Failed to update transcription status", error: error)
        }

        transcriptionTask = Task {
            defer {
                Task { @MainActor in transcriptionTask = nil }
            }

            try? await Task.sleep(nanoseconds: 500_000_000)

            guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
                AppLogger.shared.warning("❌ Audio file not found for transcription: \(audioPath)")
                await MainActor.run {
                    note.transcriptionStatus = "failed"
                    try? modelContext.save()
                }
                return
            }

            AppLogger.shared.info("🎤 Starting transcription for audio file: \(audioURL.lastPathComponent)")

            do {
                let transcript = try await HybridTranscriptionService.shared.transcribeAudioFile(url: audioURL)
                AppLogger.shared.info("✅ Transcription completed: \(transcript.count) characters")

                await MainActor.run {
                    note.content = transcript
                    note.transcriptionStatus = "completed"
                    note.title = SimpleSummaryGenerator.generateTitle(from: transcript)
                    note.aiSummary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: note.userNotes)

                    do {
                        try modelContext.save()
                        AppLogger.shared.info("✅ Successfully saved transcribed note: '\(note.title)' (\(transcript.count) chars)")
                    } catch {
                        AppLogger.shared.error("❌ Failed to save transcribed content", error: error)
                        note.transcriptionStatus = "failed"
                    }
                }
            } catch {
                AppLogger.shared.error("❌ Transcription failed on view for '\(note.title)'", error: error)
                await MainActor.run {
                    note.transcriptionStatus = "failed"
                    do {
                        try modelContext.save()
                    } catch {
                        AppLogger.shared.error("❌ Failed to update failed status", error: error)
                    }
                }
            }
        }
    }
```

- [ ] **Step 4: Cancel the in-flight task on disappear**

Find the existing `.onDisappear` block (around line 347-349) and replace it with:

```swift
        .onDisappear {
            stopPlayback()
            transcriptionTask?.cancel()
            transcriptionTask = nil
        }
```

Note: cancelling is best-effort. Once the network call to Deepgram is in flight, cancellation propagates only on the next `await` boundary. The guard on re-entry is the actual fix; cancellation is hygiene.

- [ ] **Step 5: Build**

Run:
```bash
./scripts/build.sh
```

Expected: clean build.

- [ ] **Step 6: Commit**

```bash
git add src/mobile/Muesli/Views/SimpleNoteDetailView.swift
git commit -m "fix(ios): guard transcription re-trigger race in SimpleNoteDetailView

Reopening the note sheet while transcription was running could spawn
parallel tasks with last-writer-wins on modelContext.save(). Guard
with a view-scoped Task handle; cancel on disappear."
```

---

### Task 4: Extract transcription out of NewNoteView lifecycle

**Files:**
- Create: `src/mobile/Muesli/Services/TranscriptionOrchestrator.swift`
- Modify: `src/mobile/Muesli/Views/NewNoteView.swift:501-506` (the `Task { ... }` after save)

The `Task { await attemptBatchTranscription(...) }` spawned just before `dismiss()` captures `self.modelContext` — a view-scoped reference. Move the work to a long-lived service that owns the `ModelContainer` and creates a fresh `ModelContext` for the async work. The view dismisses cleanly; transcription continues with its own context.

- [ ] **Step 1: Create the orchestrator**

Create `src/mobile/Muesli/Services/TranscriptionOrchestrator.swift` with:

```swift
//
//  TranscriptionOrchestrator.swift
//  Muesli
//
//  Long-lived service that runs post-save transcription work with a
//  ModelContext it owns, decoupled from any view's lifecycle.
//

import Foundation
import SwiftData

@MainActor
final class TranscriptionOrchestrator {
    static let shared = TranscriptionOrchestrator()

    private var container: ModelContainer?

    private init() {}

    func setContainer(_ container: ModelContainer) {
        self.container = container
    }

    /// Run batch transcription for a note. Looks up the note in a fresh context
    /// to avoid using a context from the calling view that may be deallocated.
    func enqueueTranscription(noteId: PersistentIdentifier, audioPath: String) {
        guard let container else {
            AppLogger.shared.error("TranscriptionOrchestrator has no ModelContainer; call setContainer() at app launch")
            return
        }

        Task {
            let context = ModelContext(container)
            guard let note = context.model(for: noteId) as? Note else {
                AppLogger.shared.warning("Note not found for transcription: \(noteId)")
                return
            }
            guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
                AppLogger.shared.warning("Audio file not found for transcription: \(audioPath)")
                return
            }

            AppLogger.shared.info("Orchestrator starting batch transcription for '\(note.title)'")

            do {
                let transcript = try await HybridTranscriptionService.shared.transcribeAudioFile(url: audioURL)

                note.content = transcript
                note.transcriptionStatus = "completed"
                note.title = SimpleSummaryGenerator.generateTitle(from: transcript)
                note.aiSummary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: note.userNotes)

                try context.save()
                AppLogger.shared.info("Orchestrator finished transcription for '\(note.title)' (\(transcript.count) chars)")
            } catch {
                note.transcriptionStatus = "failed"
                try? context.save()
                AppLogger.shared.error("Orchestrator transcription failed for '\(note.title)'", error: error)
            }
        }
    }
}
```

- [ ] **Step 2: Wire the container at app launch**

Open `src/mobile/Muesli/MuesliApp.swift`. The container already exists as `sharedModelContainer` (lines 13-35). Add an `init()` to the `MuesliApp` struct that hands it to the orchestrator. Replace lines 12-43 with:

```swift
@main
struct MuesliApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            AppLogger.shared.error("SwiftData container creation failed, using in-memory fallback", error: error)

            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                AppLogger.shared.error("Critical: Even in-memory container failed", error: error)
                fatalError("Could not create any ModelContainer: \(error)")
            }
        }
    }()

    init() {
        TranscriptionOrchestrator.shared.setContainer(sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            SimpleMainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

The `init()` runs once at app launch, after `sharedModelContainer` is initialized (Swift initializes stored properties before `init` body runs). Note: `setContainer` is `@MainActor`-isolated; `MuesliApp.init` is implicitly `@MainActor` because `App` is `@MainActor`-isolated. No additional annotation needed.

- [ ] **Step 3: Replace the in-view Task in NewNoteView**

In `src/mobile/Muesli/Views/NewNoteView.swift`, replace lines 501-506:

```swift
            // Attempt batch transcription if we have audio
            if let audioPath = recordingManager.currentRecordingPath {
                Task {
                    await attemptBatchTranscription(for: note, audioPath: audioPath)
                }
            }
```

with:

```swift
            // Hand batch transcription off to the long-lived orchestrator;
            // the view is about to dismiss and its modelContext should not
            // be used from an async task that outlives it.
            if let audioPath = recordingManager.currentRecordingPath {
                TranscriptionOrchestrator.shared.enqueueTranscription(
                    noteId: note.persistentModelID,
                    audioPath: audioPath
                )
            }
```

- [ ] **Step 4: Remove the now-unused attemptBatchTranscription method**

Find the method body (it starts at line ~516 in the unmodified file: `private func attemptBatchTranscription(for note: Note, audioPath: String) async`). Verify there are no other call sites:

```bash
grep -rn "attemptBatchTranscription" src/mobile/Muesli
```

Expected: only one match (the definition itself, after Step 3).

Delete the method definition (the entire `private func attemptBatchTranscription(...) async { ... }` block).

- [ ] **Step 5: Build**

Run:
```bash
./scripts/build.sh
```

Expected: clean build.

- [ ] **Step 6: Smoke test in simulator**

Run:
```bash
./scripts/build.sh && xcrun simctl boot "iPhone 16" 2>/dev/null; open -a Simulator
```

Manually: create a new note, record 5 seconds of audio, save. Verify the note appears in the list with `transcriptionStatus = completed` after a few seconds (in dev: check console output for "Orchestrator finished transcription").

- [ ] **Step 7: Commit**

```bash
git add src/mobile/Muesli/Services/TranscriptionOrchestrator.swift src/mobile/Muesli/MuesliApp.swift src/mobile/Muesli/Views/NewNoteView.swift
git commit -m "fix(ios): extract batch transcription to long-lived orchestrator

NewNoteView previously spawned a Task that captured self.modelContext
just before dismiss(). Once the view dismissed, the modelContext was
view-scoped and unsafe for the async task to use. The orchestrator
owns the ModelContainer at app scope and creates a fresh ModelContext
per transcription job."
```

---

### Task 5: Tighten CORS Joi schema (TDD)

**Files:**
- Create: `src/api/tests/unit/config.test.js`
- Modify: `src/api/src/config/index.js:28`

- [ ] **Step 1: Write failing tests for CORS validation**

Create `src/api/tests/unit/config.test.js`:

```javascript
import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';

describe('CORS configuration validation', () => {
  const ORIGINAL_ENV = { ...process.env };

  beforeEach(() => {
    jest.resetModules();
  });

  afterEach(() => {
    process.env = { ...ORIGINAL_ENV };
  });

  async function loadConfig(envOverrides) {
    process.env = { ...ORIGINAL_ENV, ...envOverrides, DEEPGRAM_API_KEY: 'test-key' };
    return import('../../src/config/index.js');
  }

  it('rejects "*" when NODE_ENV is production', async () => {
    const exit = jest.spyOn(process, 'exit').mockImplementation(() => { throw new Error('exit'); });
    await expect(loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: '*' })).rejects.toThrow();
    expect(exit).toHaveBeenCalledWith(1);
    exit.mockRestore();
  });

  it('rejects missing CORS_ORIGIN when NODE_ENV is production', async () => {
    const exit = jest.spyOn(process, 'exit').mockImplementation(() => { throw new Error('exit'); });
    await expect(loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: undefined })).rejects.toThrow();
    expect(exit).toHaveBeenCalledWith(1);
    exit.mockRestore();
  });

  it('accepts a specific origin in production', async () => {
    const { config } = await loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: 'https://muesli.app' });
    expect(config.security.corsOrigin).toEqual(['https://muesli.app']);
  });

  it('defaults to localhost in development', async () => {
    const { config } = await loadConfig({ NODE_ENV: 'development', CORS_ORIGIN: undefined });
    expect(config.security.corsOrigin).toEqual(['http://localhost:3000']);
  });

  it('parses comma-separated origins', async () => {
    const { config } = await loadConfig({ NODE_ENV: 'development', CORS_ORIGIN: 'https://a.example,https://b.example' });
    expect(config.security.corsOrigin).toEqual(['https://a.example', 'https://b.example']);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/config.test.js
```

Expected: 5 tests, multiple failures because the schema currently defaults to `'*'` and never rejects.

- [ ] **Step 3: Update the Joi schema**

In `src/api/src/config/index.js`, replace line 28:

```javascript
  CORS_ORIGIN: Joi.string().default('*'),
```

with:

```javascript
  CORS_ORIGIN: Joi.string()
    .when('NODE_ENV', {
      is: 'production',
      then: Joi.string().required().disallow('*').messages({
        'any.required': 'CORS_ORIGIN is required in production and must not be "*"',
        'any.invalid': 'CORS_ORIGIN must not be "*" in production'
      }),
      otherwise: Joi.string().default('http://localhost:3000')
    }),
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/config.test.js
```

Expected: 5 tests pass.

- [ ] **Step 5: Run full API test suite to confirm no regressions**

Run:
```bash
cd src/api && npm test
```

Expected: all tests pass.

- [ ] **Step 6: Update .env.example to document the requirement**

In `src/api/.env.example`, find the CORS_ORIGIN line and update its surrounding comment:

```bash
# CORS — required in production, must not be "*". Comma-separated for multiple origins.
# Defaults to http://localhost:3000 in development.
CORS_ORIGIN=http://localhost:3000
```

- [ ] **Step 7: Commit**

```bash
git add src/api/src/config/index.js src/api/tests/unit/config.test.js src/api/.env.example
git commit -m "fix(api): require explicit CORS_ORIGIN in production

A missing or '*' CORS_ORIGIN now fails-fast at boot in production.
Development defaults to http://localhost:3000."
```

---

### Task 6: Add redactConfig helper for safe logging (TDD)

**Files:**
- Create: `src/api/src/utils/redactConfig.js`
- Create: `src/api/tests/unit/redactConfig.test.js`
- Modify: `src/api/src/utils/logger.js` (apply as default formatter)

The current Deepgram service init log is already safe (only logs `model` and `language`). This task adds defensive infrastructure so future code can't accidentally leak secrets through Winston.

- [ ] **Step 1: Write failing tests**

Create `src/api/tests/unit/redactConfig.test.js`:

```javascript
import { describe, it, expect } from '@jest/globals';
import { redactConfig } from '../../src/utils/redactConfig.js';

describe('redactConfig', () => {
  it('redacts top-level keys matching apiKey', () => {
    const out = redactConfig({ apiKey: 'sk-secret', model: 'nova-3' });
    expect(out).toEqual({ apiKey: '[REDACTED]', model: 'nova-3' });
  });

  it('redacts case-insensitive matches for key/secret/token/password', () => {
    const out = redactConfig({
      DEEPGRAM_KEY: 'a',
      jwtSecret: 'b',
      refresh_token: 'c',
      Password: 'd',
      bundleId: 'com.example'
    });
    expect(out).toEqual({
      DEEPGRAM_KEY: '[REDACTED]',
      jwtSecret: '[REDACTED]',
      refresh_token: '[REDACTED]',
      Password: '[REDACTED]',
      bundleId: 'com.example'
    });
  });

  it('redacts nested objects', () => {
    const out = redactConfig({ deepgram: { apiKey: 'x', model: 'nova-3' } });
    expect(out).toEqual({ deepgram: { apiKey: '[REDACTED]', model: 'nova-3' } });
  });

  it('handles arrays without crashing', () => {
    const out = redactConfig({ origins: ['a', 'b'], apiKey: 'x' });
    expect(out).toEqual({ origins: ['a', 'b'], apiKey: '[REDACTED]' });
  });

  it('returns non-objects unchanged', () => {
    expect(redactConfig('hello')).toEqual('hello');
    expect(redactConfig(42)).toEqual(42);
    expect(redactConfig(null)).toEqual(null);
    expect(redactConfig(undefined)).toEqual(undefined);
  });

  it('does not mutate the input', () => {
    const input = { apiKey: 'x', model: 'y' };
    const out = redactConfig(input);
    expect(input).toEqual({ apiKey: 'x', model: 'y' });
    expect(out).not.toBe(input);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/redactConfig.test.js
```

Expected: all fail with "Cannot find module".

- [ ] **Step 3: Implement redactConfig**

Create `src/api/src/utils/redactConfig.js`:

```javascript
/**
 * Returns a deep clone of the input with values whose keys match common
 * secret patterns (key, secret, token, password) replaced with '[REDACTED]'.
 * Used as a defensive logging helper so future code can't accidentally
 * leak credentials through structured logs.
 */

const SECRET_PATTERN = /key|secret|token|password/i;

export function redactConfig(value) {
  if (value === null || value === undefined) return value;
  if (typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(redactConfig);

  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SECRET_PATTERN.test(k)) {
      out[k] = '[REDACTED]';
    } else {
      out[k] = redactConfig(v);
    }
  }
  return out;
}

export default redactConfig;
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/redactConfig.test.js
```

Expected: 6 tests pass.

- [ ] **Step 5: Apply as a Winston formatter in logger.js**

In `src/api/src/utils/logger.js`, modify the imports section. Replace lines 6-8:

```javascript
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '../config/index.js';
```

with:

```javascript
import winston from 'winston';
import DailyRotateFile from 'winston-daily-rotate-file';
import { config } from '../config/index.js';
import { redactConfig } from './redactConfig.js';

// Walk the log info object and redact secret-shaped fields. Skip the
// canonical fields (level, message, timestamp) that Winston manages.
const redactFormat = winston.format((info) => {
  const skip = new Set(['level', 'message', 'timestamp', Symbol.for('level'), Symbol.for('message'), Symbol.for('splat')]);
  for (const k of Reflect.ownKeys(info)) {
    if (skip.has(k)) continue;
    info[k] = redactConfig(info[k]);
  }
  return info;
})();
```

Then update the `logFormat` definition (lines 11-34) to prepend `redactFormat` as the first step in `winston.format.combine`. Replace the opening of `logFormat`:

```javascript
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
```

with:

```javascript
const logFormat = winston.format.combine(
  redactFormat,
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
```

Leave the rest of `logFormat` unchanged — `redactFormat` runs before timestamp/json/printf, so the latter steps see already-redacted metadata.

- [ ] **Step 6: Run full API test suite**

Run:
```bash
cd src/api && npm test
```

Expected: all tests pass, including the 6 redactConfig tests and 5 config tests from Task 5.

- [ ] **Step 7: Smoke check — log a config object**

Add a temporary line at the top of any route handler that logs the full config, e.g.:
```javascript
Logger.info('debug-redact-test', { config });
```

Start the server (`npm run dev`), hit the endpoint, observe the log output. Expected: secret-shaped fields appear as `[REDACTED]`. Remove the temporary line before committing.

- [ ] **Step 8: Commit**

```bash
git add src/api/src/utils/redactConfig.js src/api/src/utils/logger.js src/api/tests/unit/redactConfig.test.js
git commit -m "feat(api): redact secret-shaped fields in Winston logs

Adds redactConfig() helper that walks objects and replaces values whose
keys match /key|secret|token|password/i with [REDACTED]. Wired in as a
Winston formatter so all structured logs are protected by default."
```

---

## Final verification

- [ ] **iOS:** Strict-concurrency clean build
  Run: `./scripts/build.sh clean`
  Expected: no warnings on `state`, `currentRecordingPath`, `recordingDuration`, `modelContext`.

- [ ] **API:** Full test suite + lint
  Run: `cd src/api && npm test && npm run lint`
  Expected: all green.

- [ ] **Smoke test:** record → save → reopen note while transcription runs → only one transcription completes
  Manual: in simulator, create note with a long recording, save, immediately reopen the note, close, reopen. Inspect logs. Expected: only one "✅ Transcription completed" log line per note.

- [ ] **Smoke test:** API refuses to start in production without CORS_ORIGIN
  Run: `cd src/api && NODE_ENV=production DEEPGRAM_API_KEY=x node src/server.js`
  Expected: process exits with the configured error message.

- [ ] **Final commit message hygiene check:** all six task commits are present in `git log`
  Run: `git log --oneline -10`
  Expected: six new commits matching the messages above, plus prior history.
