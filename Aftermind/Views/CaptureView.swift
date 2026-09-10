import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var recording = RecordingService()
    private let transcriptionService = AppConfig.transcriptionService
    private let extractionService = ContextExtractor.service
    
    // UI States
    @State private var showPermissionDenied = false
    @State private var phase: ProcessingPhase = .idle
    @State private var transcript: String?
    @State private var errorMessage: String?
    @State private var savedSession: SessionModel?

    enum ProcessingPhase {
        case idle, recording, transcribing, extracting, saved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: iconName)
                        .font(.system(size: 64))
                        .foregroundStyle(iconColor)
                        .padding(.top, 24)

                    Text(statusTitle)
                        .font(.title2.monospacedDigit())

                    Button {
                        Task { await toggle() }
                    } label: {
                        Text(buttonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(buttonColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(phase == .transcribing || phase == .extracting)
                    .padding(.horizontal, 32)

                    if phase == .transcribing || phase == .extracting {
                        ProgressView("Processing audio...")
                    }
                    
                    if let transcript, phase != .idle {
                        GroupBox("Transcript") {
                            Text(transcript)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    if let savedSession {
                        GroupBox("Context Saved!") {
                            Text(savedSession.summary)
                                .font(.callout)
                            Text("\(savedSession.items.count) memory items extracted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 24)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Capture")
            .alert("Microphone access denied", isPresented: $showPermissionDenied) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Enable microphone access in Settings.")
            }
        }
    }

    // MARK: - UI Helpers

    private var iconName: String {
        switch phase {
        case .recording: return "waveform"
        case .saved: return "checkmark.circle.fill"
        default: return "mic.fill"
        }
    }

    private var iconColor: Color {
        switch phase {
        case .recording: return .red
        case .saved: return .green
        default: return .blue
        }
    }

    private var statusTitle: String {
        switch phase {
        case .idle: return "Ready to listen"
        case .recording: return formatted(recording.elapsedSeconds)
        case .transcribing: return "Transcribing..."
        case .extracting: return "Extracting context..."
        case .saved: return "Saved to memory"
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

    private var buttonColor: Color {
        switch phase {
        case .recording: return .red
        case .saved: return .blue
        case .transcribing, .extracting: return .gray
        default: return .blue
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
