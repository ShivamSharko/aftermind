import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [SessionModel]

    @StateObject private var recording = RecordingService()
    private let transcriptionService = AppConfig.transcriptionService
    private let extractionService = ContextExtractor.service

    @State private var showPermissionDenied = false
    @State private var phase: ProcessingPhase = .idle
    @State private var transcript: String?
    @State private var errorMessage: String?
    @State private var savedSession: SessionModel?
    @State private var seedError = false

    enum ProcessingPhase {
        case idle, recording, transcribing, extracting, saved
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
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
                        CircleIconButton(systemName: "sparkles", action: seedDemoSession)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        Text("Aftermind remembers so you don't have to.")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            PillChip(title: phaseChip, isSelected: true)
                            PillChip(title: "\(sessions.count) sessions", isSelected: false)
                            if AppConfig.useMockTranscription {
                                PillChip(title: "demo mode", isSelected: false)
                            }
                        }
                    }

                    micCard

                    Button {
                        Task { await toggle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: buttonIcon)
                            Text(buttonTitle)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(phase == .recording ? .white : (phase == .transcribing || phase == .extracting ? .white : .black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(buttonColor)
                        .clipShape(Capsule())
                        .shadow(color: buttonColor.opacity(0.35), radius: 16, y: 6)
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(phase == .transcribing || phase == .extracting)

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
                        }
                        .padding(16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.accent.opacity(0.35), lineWidth: 1))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.50))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
        }
    }

    private var micCard: some View {
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
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

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
        case .idle: return "Aftermind will listen, transcribe and extract context"
        case .recording: return "Listening... tap stop when the conversation ends"
        case .transcribing: return "Turning audio into text"
        case .extracting: return "Finding what is worth remembering"
        case .saved: return "Check the Memory tab or ask in Chat"
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .idle: return "Start listening"
        case .recording: return "Stop listening"
        case .transcribing, .extracting: return "Processing..."
        case .saved: return "Record another"
        }
    }

    private var buttonIcon: String {
        switch phase {
        case .idle: return "mic.fill"
        case .recording: return "stop.fill"
        case .transcribing, .extracting: return "hourglass"
        case .saved: return "plus"
        }
    }

    private var buttonColor: Color {
        switch phase {
        case .recording: return Color(red: 0.95, green: 0.30, blue: 0.35)
        case .transcribing, .extracting: return Color.white.opacity(0.20)
        default: return Theme.accent
        }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func toggle() async {
        switch phase {
        case .idle:
            let granted = await recording.requestMicrophonePermission()
            guard granted else { showPermissionDenied = true; return }
            resetState()
            recording.start()
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
    }

    private func seedDemoSession() {
        Task {
            do {
                let extracted = try await MockContextExtractionService().extract(from: "demo")
                let session = SessionModel(
                    createdAt: Date(),
                    summary: extracted.session_summary,
                    transcript: "Demo session loaded for testing and demonstration.",
                    topics: extracted.topics
                )
                modelContext.insert(session)
                for item in extracted.items {
                    let memoryItem = MemoryItemModel(
                        type: item.type,
                        title: item.title,
                        detail: item.description,
                        people: item.related_people,
                        evidence: item.evidence,
                        confidence: item.confidence,
                        dueText: item.due_text
                    )
                    memoryItem.session = session
                    modelContext.insert(memoryItem)
                }
                try modelContext.save()
            } catch {
                seedError = true
            }
        }
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
                    topics: []
                )
                modelContext.insert(incomplete)
                try modelContext.save()
                savedSession = incomplete
                errorMessage = "Extraction failed after 2 attempts: \(lastError?.localizedDescription ?? "unknown error"). Raw transcript saved."
                phase = .saved
                return
            }

            let session = SessionModel(
                createdAt: Date(),
                summary: extracted.session_summary,
                transcript: result.text,
                topics: extracted.topics
            )
            modelContext.insert(session)

            for item in extracted.items {
                let memoryItem = MemoryItemModel(
                    type: item.type,
                    title: item.title,
                    detail: item.description,
                    people: item.related_people,
                    evidence: item.evidence,
                    confidence: item.confidence,
                    dueText: item.due_text
                )
                memoryItem.session = session
                modelContext.insert(memoryItem)
            }

            try modelContext.save()
            savedSession = session
            phase = .saved

        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }
}
