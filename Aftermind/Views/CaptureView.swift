import SwiftUI
import SwiftData

struct CaptureView: View {
    var onOpenMemory: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SessionModel]
    @Query(sort: \MemoryItemModel.createdAt, order: .reverse) private var allItems: [MemoryItemModel]

    private var openItems: [MemoryItemModel] {
        allItems.filter { item in
            (item.type == "commitment" || item.type == "task") &&
            item.status != "done" &&
            item.status != "completed"
        }
    }

    @StateObject private var recording = RecordingService()
    private var transcriptionService: TranscriptionServiceProtocol { AppConfig.transcriptionService }
    private var extractionService: ContextExtractionServiceProtocol { ContextExtractor.service }

    @State private var showPermissionDenied = false
    @State private var phase: ProcessingPhase = .idle
    @State private var transcript: String?
    @State private var errorMessage: String?
    @State private var savedSession: SessionModel?
    @State private var seedError = false
    @State private var duplicateCount = 0
    @State private var showDemoInfo = false
    @State private var showKeyAlert = false
    @State private var keyInput = ""

    enum ProcessingPhase {
        case idle, recording, transcribing, extracting, saved
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    greetingSection
                    chipsSection
                    micCard
                    focusSection
                    transcriptSection
                    savedSection
                    errorSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 110)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Microphone access denied", isPresented: $showPermissionDenied) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Enable microphone access in Settings.")
            }
            .alert("Could not load demo session", isPresented: $seedError) {
                Button("OK", role: .cancel) { }
            }
            .alert("Demo mode", isPresented: $showDemoInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(AppConfig.useMockTranscription
                     ? "Demo mode is ON: transcription, extraction and chat run on local mocks, so the whole product works with zero setup. To go live: paste a Groq key via the gear icon, then set useMockTranscription = false in AppConfig.swift."
                     : "Live mode: using your Groq key for transcription, extraction and chat.")
            }
            .alert("Groq API key", isPresented: $showKeyAlert) {
                TextField("Paste your key", text: $keyInput)
                Button("Save") {
                    let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { AppConfig.groqAPIKey = trimmed }
                    keyInput = ""
                }
                Button("Cancel", role: .cancel) { keyInput = "" }
            } message: {
                Text("Stored securely in the iOS Keychain.")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Theme.purpleLight, Theme.purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                Text("A")
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
            }
            Spacer()
            CircleIconButton(systemName: "gearshape.fill") { showKeyAlert = true }
            CircleIconButton(systemName: "sparkles", action: seedDemoSession)
        }
        .padding(.top, 12)
    }

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            Text("Aftermind remembers so you don't have to.")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var chipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PillChip(title: phaseChip, isSelected: true)
                PillChip(title: "\(sessions.count) sessions", isSelected: false, action: onOpenMemory)
                PillChip(title: AppConfig.useMockTranscription ? "demo mode" : "live mode", isSelected: false) { showDemoInfo = true }
            }
        }
    }

    private var micCard: some View {
        Button {
            Task { await toggle() }
        } label: {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(phase == .recording ? 0.22 : 0.10))
                        .frame(width: 150, height: 150)
                        .blur(radius: 10)
                    Circle()
                        .fill(LinearGradient(colors: [Theme.purpleLight, Theme.purpleDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 112, height: 112)
                        .shadow(color: Theme.purpleDeep.opacity(0.6), radius: 24, y: 10)
                    Image(systemName: phase == .recording ? "waveform" : "mic.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse, options: .repeating, isActive: phase == .recording)
                }
                Text(statusTitle)
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(phase == .recording ? Theme.accent.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(PressableStyle())
        .disabled(phase == .transcribing || phase == .extracting)
    }

    @ViewBuilder
    private var focusSection: some View {
        if !openItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bolt.fill").foregroundColor(Theme.accent)
                    Text("Open Focus").font(.headline).foregroundColor(.white)
                    Spacer()
                    Text("\(openItems.count)").font(.caption.bold()).foregroundColor(Theme.accent)
                }
                ForEach(openItems.prefix(2)) { item in
                    HStack(spacing: 10) {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        Text(item.title).font(.subheadline).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                        Spacer()
                        if let due = item.dueDate {
                            Text(due.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundColor(Theme.accent)
                        } else if let due = item.dueText {
                            Text(due).font(.caption2).foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.2), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if let transcript, phase != .idle {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Transcript")
                Text(transcript)
                    .font(.callout)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    @ViewBuilder
    private var savedSection: some View {
        if let savedSession {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.accent).frame(width: 40, height: 40)
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved to memory")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(savedSession.items.count) memories extracted")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                }
                Text(savedSession.summary)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.85))
                if duplicateCount > 0 {
                    Text("Skipped \(duplicateCount) duplicate memories already stored.")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                if let path = savedSession.audioPath, savedSession.transcript.isEmpty {
                    Button {
                        Task { await retryTranscription(session: savedSession, path: path) }
                    } label: {
                        Label("Retry transcription", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.50))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - UI helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var phaseChip: String {
        switch phase {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .extracting: return "Extracting"
        case .saved: return "Saved"
        }
    }

    private var statusTitle: String {
        switch phase {
        case .idle: return "Tap to begin"
        case .recording: return formatted(recording.elapsedSeconds)
        case .transcribing: return "Transcribing"
        case .extracting: return "Extracting"
        case .saved: return "Done"
        }
    }

    private var statusSubtitle: String {
        switch phase {
        case .idle: return "One tap on this card starts and stops the capture"
        case .recording: return "Listening... tap the card to stop"
        case .transcribing: return "Turning audio into text"
        case .extracting: return "Finding what is worth remembering"
        case .saved: return "Saved - tap the card to record another"
        }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Actions

    private func toggle() async {
        switch phase {
        case .idle:
            let granted = await recording.requestMicrophonePermission()
            guard granted else { showPermissionDenied = true; return }
            resetState()
            let started = recording.start()
            guard started else {
                errorMessage = recording.errorMessage ?? "Could not start the audio session."
                return
            }
            phase = .recording
        case .recording:
            let url = recording.stop()
            guard let url else { return }
            await processPipeline(url: url)
        case .saved:
            resetState()
        default: break
        }
    }

    private func resetState() {
        phase = .idle
        transcript = nil
        savedSession = nil
        errorMessage = nil
        duplicateCount = 0
    }

    private func seedDemoSession() {
        Task {
            do {
                _ = try await DemoSeedService.seed(into: modelContext)
            } catch {
                seedError = true
            }
        }
    }

    private func retainAudio(_ url: URL) -> String? {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AftermindRecordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest.path
        } catch {
            return nil
        }
    }

    private func retryTranscription(session: SessionModel, path: String) async {
        let url = URL(fileURLWithPath: path)
        modelContext.delete(session)
        try? modelContext.save()
        savedSession = nil
        await processPipeline(url: url)
    }

    private func processPipeline(url: URL) async {
        phase = .transcribing
        do {
            let result = try await transcriptionService.transcribe(audioURL: url)
            transcript = result.text

            phase = .extracting

            var extracted: ExtractedSession?
            var lastError: Error?
            for _ in 0..<2 {
                do {
                    extracted = try await extractionService.extract(from: result.text)
                    lastError = nil
                    break
                } catch {
                    lastError = error
                }
            }

            guard let extracted else {
                let incomplete = SessionModel(
                    createdAt: Date(),
                    summary: "Processing incomplete - raw transcript saved.",
                    transcript: result.text,
                    topics: [],
                    audioPath: retainAudio(url)
                )
                modelContext.insert(incomplete)
                try modelContext.save()
                savedSession = incomplete
                errorMessage = "Extraction failed after 2 attempts: \(lastError?.localizedDescription ?? "unknown error"). Raw transcript saved."
                phase = .saved
                return
            }

            let existingItems = (try? modelContext.fetch(FetchDescriptor<MemoryItemModel>())) ?? []

            let session = SessionModel(
                createdAt: Date(),
                summary: extracted.session_summary,
                transcript: result.text,
                topics: extracted.topics
            )
            modelContext.insert(session)

            for item in extracted.items {
                let text = "\(item.title) \(item.description) \(item.evidence)"
                let vec = EmbeddingService.shared.vector(for: text)
                if let vec, existingItems.contains(where: { old in
                    guard let oldVec = old.embedding else { return false }
                    return EmbeddingService.shared.cosine(vec, oldVec) > 0.93
                }) {
                    duplicateCount += 1
                    continue
                }
                let memoryItem = MemoryItemModel(
                    type: item.type,
                    title: item.title,
                    detail: item.description,
                    people: item.related_people,
                    evidence: item.evidence,
                    confidence: item.confidence,
                    dueText: item.due_text,
                    owner: item.owner,
                    dueDate: DateParsing.isoDate(item.due_date),
                    embedding: vec,
                    tags: item.tags,
                    status: item.status
                )
                memoryItem.session = session
                modelContext.insert(memoryItem)
                NotificationService.schedule(for: memoryItem)
            }

            try modelContext.save()
            savedSession = session
            phase = .saved

        } catch {
            let path = retainAudio(url)
            let failed = SessionModel(
                createdAt: Date(),
                summary: "Transcription failed - audio retained for retry.",
                transcript: "",
                topics: [],
                audioPath: path
            )
            modelContext.insert(failed)
            try? modelContext.save()
            savedSession = failed
            errorMessage = "Transcription failed: \(error.localizedDescription). Audio retained."
            phase = .saved
        }
    }
}
