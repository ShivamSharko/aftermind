import Foundation
import AVFoundation

final class RecordingService: ObservableObject {

    @Published var isRecording = false
    @Published var elapsedSeconds = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var recordingURL: URL?

    // MARK: - Permission

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    @discardableResult
    func start() -> Bool {
        Task.detached(priority: .userInitiated) {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                await MainActor.run { self.errorMessage = "Audio session failed: \(error.localizedDescription)" }
                return
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
                recorder.prepareToRecord()
                recorder.record()
                await MainActor.run {
                    self.recorder = recorder
                    self.recordingURL = url
                    self.isRecording = true
                    self.elapsedSeconds = 0
                    self.startTimer()
                }
            } catch {
                await MainActor.run { self.errorMessage = "Could not start recording: \(error.localizedDescription)" }
            }
        }
        return true
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        stopTimer()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return recordingURL
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedSeconds += 1
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

