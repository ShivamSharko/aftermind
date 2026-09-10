# Aftermind

A personal context notetaker for iOS. Aftermind listens to a conversation, transcribes it, extracts **what is actually worth remembering** as typed memory objects (commitments, decisions, tasks, facts, ideas), stores them locally, and lets you chat with that memory — not with the raw transcript.

## Demo
[VIDEO_LINK]

## What I built
The core loop, end to end: **Record → Transcribe → Clean/Structure → Store → Chat**
- **Capture tab:** microphone recording with live timer, permission handling, and a visible pipeline (Transcribing → Extracting → Saved).
- **Memory tab:** sessions → typed memory items with people, due info, evidence snippets and confidence scores. A "Load demo session" button guarantees a demoable state.
- **Chat tab:** grounded Q&A over structured memory ("What did I promise to do?", "What did Sarah say she would send?"), with source citations under each answer.

## Product decisions
1. **Transcription is not the product.** A raw transcript is noise-heavy; the value is the layer between recording and user.
2. **Typed memory objects, not transcript chunks.** Commitments, tasks, decisions, facts and ideas are first-class records, because the interesting questions ("what did I promise?") are entity- and action-oriented, not semantic-similarity-oriented.
3. **Every memory carries evidence + confidence.** Each item stores the exact transcript snippet it came from, so answers are auditable and hallucination-resistant.
4. **Chat retrieves structured items, never a transcript dump.** Intent parsing + weighted retrieval → grounded prompt → cited answer.
5. **Mock-first development.** Every external dependency (transcription, extraction) has a mock implementation behind a protocol, so the product is demoable with zero API keys (the assignment explicitly permits mocking).
6. **What I chose NOT to build:** ambient/background listening, accounts or a backend, speaker diarization, and a vector database. Each adds risk without strengthening the core loop in a 24-hour window.

## What is worth remembering (signal vs noise)
**Kept:** commitments, decisions, tasks + deadlines, facts about people, preferences, ideas, relationship context.
**Discarded:** filler, small talk, repetitions, transient logistics, unrecoverable references.
**Signal test:** Will this matter in a week or a month? Does it bind someone to an action? Does it describe a person, project, or preference? These rules are encoded in the extraction system prompt.

## Context schema
`Session` — summary, topics, participants, raw transcript (kept only as provenance).
`MemoryItem` — type, title, detail, people[], dueText, evidence, confidence, tags, link to session.
Relationships: items cascade-delete with their session; people and topics connect items across sessions for future graph-style retrieval.

## Technical architecture
Audio (AVAudioRecorder) → TranscriptionService (Groq whisper-large-v3) → ContextExtractionService (Groq openai/gpt-oss-120b, JSON mode) → SwiftData → ChatRetrievalService → grounded LLM answer.
- SwiftUI + SwiftData (iOS 17), async/await throughout, protocol-based services with Groq + Mock implementations, typed errors surfaced as alerts and UI states, extraction retried once with an "incomplete session" fallback so no recording is ever lost.

## How chat retrieves context
1. Intent parsing: item-type keywords (promise/commit → commitment, task, idea, decision, preference, fact), person names detected from stored memories, and date ranges ("today", "yesterday", "last week").
2. Weighted scoring per memory: 0.35 keyword match + 0.20 person match + 0.20 type match + 0.15 recency (exponential decay) + 0.10 confidence.
3. Top-5 items formatted with their evidence into the system prompt.
4. The LLM is instructed to answer **only** from that context and to admit gaps; the UI shows the source memories under each answer.
This keeps token use small, answers citable, and prevents the model from inventing memories.

## Assumptions & limitations
- Groq free tier (rate-limited); demo recordings kept short.
- Retrieval is keyword + metadata + recency scoring; no embeddings yet.
- No speaker diarization — single-speaker transcript assumed.
- Relative due dates kept as text (`dueText`), not normalized to calendar dates.
- API key lives in `AppConfig` for prototype speed; Keychain + on-device encryption would be the production path.
- Simulator microphone depends on host hardware; "Load demo session" and mock mode guarantee a demoable state.

## With another week
- Embeddings + hybrid retrieval (sqlite-vec) with reranking.
- Speaker diarization → per-person memory and a lightweight people graph.
- Memory dedup/merge and temporal normalization ("tonight" → real date).
- Commitment lifecycle (open → done) and proactive reminders.
- Ambient listening behind an explicit privacy budget: on-device voice-activity trigger, retention policy, user-visible capture log.

## Setup
1. Free Groq key: https://console.groq.com/keys → paste into `Aftermind/Support/AppConfig.swift`, set `useMockTranscription = false` (leave `true` for a zero-setup demo).
2. On macOS: `brew install xcodegen && xcodegen generate && open Aftermind.xcodeproj`, run on an iOS 17+ simulator.
