import Foundation
import AVFoundation

final class RecordingService: ObservableObject {
    @Published var isRecording = false
    @Published var elapsedSeconds = 0
    @Published var errorMessage: String?
    @Published var soundLevel: Double = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    @discardableResult
    func start() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session failed: \(error.localizedDescription)"
            return false
        }

        let fileName = "aftermind-\(Int(Date().timeIntervalSince1970)).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            recorder.record()
            self.recorder = recorder
            self.recordingURL = url
            self.isRecording = true
            self.elapsedSeconds = 0
            self.soundLevel = 0
            startTimers()
            return true
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            return false
        }
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        stopTimers()
        isRecording = false
        soundLevel = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recordingURL
    }

    private func startTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.elapsedSeconds += 1 }
        }
        RunLoop.current.add(timer!, forMode: .common)

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder else { return }
            recorder.updateMeters()
            let db = recorder.averagePower(forChannel: 0)
            let normalized = max(0, min(1, Double((db + 50) / 50)))
            DispatchQueue.main.async {
                self.soundLevel = normalized
            }
        }
        RunLoop.current.add(levelTimer!, forMode: .common)
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
    }
}
