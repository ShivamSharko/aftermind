# Aftermind

A personal context notetaker for iOS. Aftermind listens to a conversation, transcribes it, extracts **what is actually worth remembering** as typed memory objects (commitments, decisions, tasks, facts, ideas), stores them locally, and lets you chat with that memory — not with the raw transcript.

## Demo
[VIDEO_LINK]

## What I built
The core loop, end to end: **Record → Transcribe → Clean/Structure → Store → Chat**
- **Capture tab:** microphone recording with live timer, permission handling, and a visible pipeline (Transcribing → Extracting → Saved).
- **Memory tab:** sessions → typed memory items with people, due info, evidence snippets and confidence scores. A "Load demo session" button guarantees a demoable state. Swipe-to-delete with confirmation on sessions and items gives full user control over retained data.
- **Chat tab:** grounded Q&A over structured memory ("What did I promise to do?", "What did Sarah say she would send?"), with source citations under each answer.

## Product decisions
1. **Transcription is not the product.** A raw transcript is noise-heavy; the value is the layer between recording and user.
2. **Typed memory objects, not transcript chunks.** Commitments, tasks, decisions, facts and ideas are first-class records, because the interesting questions ("what did I promise?") are entity- and action-oriented, not semantic-similarity-oriented.
3. **Every memory carries evidence + confidence.** Each item stores the exact transcript snippet it came from, so answers are auditable and hallucination-resistant.
4. **Chat retrieves structured items, never a transcript dump.** Intent parsing + weighted retrieval → grounded prompt → cited answer.
5. **Mock-first development.** Every external dependency (transcription, extraction, chat answering) has a mock implementation behind a protocol, so the product is demoable with zero API keys (the assignment explicitly permits mocking).
6. **What I chose NOT to build:** ambient/background listening, accounts or a backend, speaker diarization, and a vector database. Each adds risk without strengthening the core loop in a 24-hour window.

## What is worth remembering (signal vs noise)
**Kept:** commitments, decisions, tasks + deadlines, facts about people, preferences, ideas, relationship context.
**Discarded:** filler, small talk, repetitions, transient logistics, unrecoverable references.
**Signal test:** Will this matter in a week or a month? Does it bind someone to an action? Does it describe a person, project, or preference? These rules are encoded in the extraction system prompt.

## Context schema
`Session` — summary, topics, participants, raw transcript (kept only as provenance).
`MemoryItem` — type, title, detail, owner ("user" or a person's name), people[], dueText plus resolved dueDate, evidence, confidence, tags, link to session.
The schema ships six item types (commitment, task, decision, fact, idea, preference); the longer candidate list was intentionally folded in — deadlines live on commitments/tasks as resolved dueDates, people as owner/related_people — to keep extraction precision high instead of spreading confidence across eleven sparse categories.
Relationships: items cascade-delete with their session; people and topics connect items across sessions for future graph-style retrieval.

## Technical architecture
Audio (AVAudioRecorder) → TranscriptionService (Groq whisper-large-v3) → ContextExtractionService (Groq openai/gpt-oss-120b, JSON mode) → SwiftData → ChatRetrievalService → grounded LLM answer.
- SwiftUI + SwiftData (iOS 17), async/await throughout, protocol-based services with Groq + Mock implementations, typed errors surfaced as alerts and UI states, extraction retried once with an "incomplete session" fallback so no recording is ever lost.

## How chat retrieves context
1. Intent parsing: item-type keywords (promise/commit → commitment, task, idea, decision, preference, fact), person names detected from stored memories, and rolling date windows ("today", "yesterday", "last week" = past 7 days).
2. Hybrid weighted scoring per memory: 0.30 keyword match + 0.18 person match + 0.15 type match + 0.15 on-device semantic similarity (Apple NaturalLanguage sentence embeddings, cosine distance) + 0.12 recency (exponential decay) + 0.10 confidence.
3. Top-5 items formatted with their evidence into the system prompt.
4. The LLM is instructed to answer **only** from that context and to admit gaps; the UI shows the source memories under each answer.
This keeps token use small, answers citable, and prevents the model from inventing memories.

## Assumptions & limitations
- Groq free tier (rate-limited); demo recordings kept short.
- Retrieval blends lexical, metadata, recency and on-device sentence embeddings; a dedicated vector index (e.g. sqlite-vec) would scale it further.
- Retrieval scores the 50 most recent memories per query; a dedicated vector index would remove this cap.
- No speaker diarization — single-speaker transcript assumed.
- Relative due dates kept as text (`dueText`), not normalized to calendar dates.
- API keys are entered via the in-app Settings sheet and stored in the iOS Keychain; no secrets ship with the repository.
- Simulator microphone depends on host hardware; "Load demo session" and mock mode guarantee a demoable state.
- Chat history is in-memory per launch; persisting conversations across launches is a follow-up.
- Microphone interruptions (phone calls, Siri) stop recording without auto-resume; the retained-audio fallback preserves the session so nothing is lost.
- Date filters are rolling windows ("last week" = past 7 days), not calendar weeks.

## Advanced Engineering Features
- **Semantic Deduplication & Hybrid Search:** Uses Apple's on-device `NaturalLanguage` sentence embeddings to prevent duplicate memories on save and power semantic chat retrieval (no cloud vector DB needed).
- **Temporal Normalization:** The LLM resolves relative dates ("Friday") into absolute ISO dates, enabling native iOS local notifications for proactive reminders.
- **Semantic Diarization (Ownership):** Instead of relying on expensive audio diarization APIs, the extraction prompt infers task ownership ("user" vs "Sarah") directly from conversational context.
- **Security:** API keys are stored securely in the iOS Keychain, not in plain text.
- **Failure recovery:** failed transcriptions retain the audio on-device and expose a one-tap "Retry transcription" action from the Capture screen, so no recording is ever lost.
- **Unified demo seeding:** "Load demo session" runs the same pipeline as real capture (on-device embeddings, ownership, resolved dates, notifications), so demo data exercises every retrieval path equally.

## With another week
- Dedicated vector index (sqlite-vec) + cross-encoder reranking for scale.
- Speaker diarization → per-person memory and a lightweight people graph.
- Richer memory merging (conflict resolution when a fact changes); temporal normalization and dedup are already implemented at extraction/save time.
- Commitment lifecycle (open → done) and proactive reminders.
- Ambient listening behind an explicit privacy budget: on-device voice-activity trigger, retention policy, user-visible capture log.

## Setup
1. **Zero-key demo mode (default):** with `useMockTranscription = true`, transcription, extraction AND chat answering are all mocked behind protocols, so the entire product is explorable with no accounts or keys.
2. **Real mode:** create a free Groq key at https://console.groq.com/keys, run the app, tap the settings (gear) icon on the Capture tab and paste the key (stored in the iOS Keychain), then set `useMockTranscription = false` in `Aftermind/Support/AppConfig.swift`.
3. On macOS: `brew install xcodegen && xcodegen generate && open Aftermind.xcodeproj`, run on an iOS 17+ simulator.
