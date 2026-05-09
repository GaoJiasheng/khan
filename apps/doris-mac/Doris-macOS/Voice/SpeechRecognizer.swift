import Foundation
import Speech
import AVFoundation
import DorisIPC

/// Thin wrapper around `SFSpeechRecognizer` + `AVAudioEngine` that streams a
/// running transcription while the user holds the trigger key. Stops cleanly
/// when `stop()` is called and resolves the final transcript.
@MainActor
final class SpeechRecognizer {
    /// Result of a single capture session.
    struct Result {
        var text: String
        /// True when the recognizer signaled `result.isFinal`. False on
        /// graceful early stop where we just take the latest partial.
        var isFinal: Bool
    }

    /// Authorization state for both speech recognition AND microphone access.
    /// Both are required; we expose them as one combined gate so the UI can
    /// give the user a single "you need to grant X" prompt path.
    enum Authorization {
        case granted
        case deniedSpeech
        case deniedMicrophone
        case restricted
        case notYetDetermined
    }

    /// On-going partial transcript callback (UI shows this live).
    var onPartial: ((String) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private let engine = AVAudioEngine()
    private var lastPartial: String = ""

    init(locale: Locale = .current) {
        let supported = SFSpeechRecognizer.supportedLocales()
        let pick: Locale
        if supported.contains(locale) {
            pick = locale
        } else if let base = supported.first(where: { $0.identifier.hasPrefix(locale.language.languageCode?.identifier ?? "") }) {
            pick = base
        } else {
            pick = Locale(identifier: "en-US")
        }
        self.recognizer = SFSpeechRecognizer(locale: pick)
        DorisLog.voice.info("recognizer locale=\(pick.identifier, privacy: .public) requested=\(locale.identifier, privacy: .public) supportedCount=\(supported.count, privacy: .public)")
    }

    static func requestAuthorization() async -> Authorization {
        // 1. Speech framework permission
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        switch speechStatus {
        case .authorized: break
        case .denied:     return .deniedSpeech
        case .restricted: return .restricted
        case .notDetermined: return .notYetDetermined
        @unknown default: return .restricted
        }

        // 2. Microphone permission (AVCaptureDevice on macOS).
        let micGranted: Bool = await withCheckedContinuation { c in
            AVCaptureDevice.requestAccess(for: .audio) { c.resume(returning: $0) }
        }
        return micGranted ? .granted : .deniedMicrophone
    }

    static func currentAuthorization() -> Authorization {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .denied:     return .deniedSpeech
        case .restricted: return .restricted
        case .notDetermined: return .notYetDetermined
        case .authorized:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:    return .granted
            case .denied:        return .deniedMicrophone
            case .restricted:    return .restricted
            case .notDetermined: return .notYetDetermined
            @unknown default:    return .restricted
            }
        @unknown default: return .restricted
        }
    }

    enum RecognizerError: LocalizedError {
        case unauthorized
        case unsupported
        case audioInputUnavailable
        case alreadyRunning

        var errorDescription: String? {
            switch self {
            case .unauthorized:           return "Speech / microphone access not granted."
            case .unsupported:            return "Speech recognition isn't available for the current locale."
            case .audioInputUnavailable:  return "No microphone input available."
            case .alreadyRunning:         return "Recognizer is already running."
            }
        }
    }

    func start() throws {
        guard task == nil else { throw RecognizerError.alreadyRunning }
        guard let recognizer, recognizer.isAvailable else {
            DorisLog.voice.error("recognizer not available (locale unsupported / offline model missing)")
            throw RecognizerError.unsupported
        }
        guard Self.currentAuthorization() == .granted else {
            throw RecognizerError.unauthorized
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // We *don't* force on-device recognition. On many locales (esp.
        // mixed Chinese/English) the offline model either isn't downloaded
        // or produces no partial results. Letting Speech framework choose
        // server-vs-on-device per-locale is far more reliable.
        request.requiresOnDeviceRecognition = false
        self.request = request
        self.lastPartial = ""

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        DorisLog.voice.info("input node sampleRate=\(format.sampleRate, privacy: .public) channels=\(format.channelCount, privacy: .public)")
        guard format.sampleRate > 0 else {
            throw RecognizerError.audioInputUnavailable
        }
        inputNode.removeTap(onBus: 0)
        var bufferCount = 0
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buf, _ in
            request?.append(buf)
            bufferCount += 1
            if bufferCount == 1 || bufferCount == 30 {
                DorisLog.voice.info("audio buffers tapped: \(bufferCount, privacy: .public)")
            }
        }

        engine.prepare()
        try engine.start()
        DorisLog.voice.info("audio engine running")

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let error {
                let nsErr = error as NSError
                DorisLog.voice.error("recognition error code=\(nsErr.code, privacy: .public) domain=\(nsErr.domain, privacy: .public) desc=\(error.localizedDescription, privacy: .public)")
            }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.lastPartial = text
                    self.onPartial?(text)
                }
            }
        }
    }

    /// Stop the current session and resolve the most recent transcript.
    func stop() async -> Result {
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)

        // Give the recognizer a brief moment to flush its last buffer into a
        // final transcript. This keeps the tail of the user's last word from
        // being chopped off when they release the key quickly.
        try? await Task.sleep(nanoseconds: 250_000_000)

        task?.finish()
        task = nil
        request = nil

        let text = lastPartial.trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(text: text, isFinal: !text.isEmpty)
    }
}
