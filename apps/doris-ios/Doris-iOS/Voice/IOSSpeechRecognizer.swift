import Foundation
import Speech
import AVFoundation

/// iOS port of the Mac SpeechRecognizer. Differences:
///
/// - Configures `AVAudioSession` (record category) before starting the
///   audio engine — iOS requires this; macOS doesn't.
/// - No on-device flag: iOS handles model availability internally.
@MainActor
final class IOSSpeechRecognizer {
    struct Result {
        var text: String
        var isFinal: Bool
    }

    enum Authorization {
        case granted
        case deniedSpeech
        case deniedMicrophone
        case restricted
        case notYetDetermined
    }

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
        } else if let base = supported.first(where: {
            $0.identifier.hasPrefix(locale.language.languageCode?.identifier ?? "")
        }) {
            pick = base
        } else {
            pick = Locale(identifier: "en-US")
        }
        self.recognizer = SFSpeechRecognizer(locale: pick)
    }

    static func requestAuthorization() async -> Authorization {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        switch speechStatus {
        case .authorized: break
        case .denied:        return .deniedSpeech
        case .restricted:    return .restricted
        case .notDetermined: return .notYetDetermined
        @unknown default:    return .restricted
        }

        let micGranted: Bool = await withCheckedContinuation { c in
            AVAudioApplication.requestRecordPermission { c.resume(returning: $0) }
        }
        return micGranted ? .granted : .deniedMicrophone
    }

    static func currentAuthorization() -> Authorization {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .denied:        return .deniedSpeech
        case .restricted:    return .restricted
        case .notDetermined: return .notYetDetermined
        case .authorized:
            switch AVAudioApplication.shared.recordPermission {
            case .granted:    return .granted
            case .denied:     return .deniedMicrophone
            case .undetermined: return .notYetDetermined
            @unknown default: return .restricted
            }
        @unknown default: return .restricted
        }
    }

    enum RecognizerError: LocalizedError {
        case unauthorized
        case unsupported
        case audioSessionFailed(String)
        case alreadyRunning

        var errorDescription: String? {
            switch self {
            case .unauthorized:      return "Microphone or speech access not granted."
            case .unsupported:       return "Speech recognition isn't available for this locale."
            case .audioSessionFailed(let m): return "Audio session: \(m)"
            case .alreadyRunning:    return "Recognizer is already running."
            }
        }
    }

    func start() throws {
        guard task == nil else { throw RecognizerError.alreadyRunning }
        guard let recognizer, recognizer.isAvailable else {
            throw RecognizerError.unsupported
        }
        guard Self.currentAuthorization() == .granted else {
            throw RecognizerError.unauthorized
        }

        // Configure the audio session for recording. `.record` keeps the
        // session lightweight; `.measurement` mode disables system audio
        // processing that can chop the start of the user's first word.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw RecognizerError.audioSessionFailed(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.request = request
        self.lastPartial = ""

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buf, _ in
            request?.append(buf)
        }

        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.lastPartial = text
                    self.onPartial?(text)
                }
            }
        }
    }

    func stop() async -> Result {
        request?.endAudio()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        try? await Task.sleep(nanoseconds: 250_000_000)

        task?.finish()
        task = nil
        request = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let text = lastPartial.trimmingCharacters(in: .whitespacesAndNewlines)
        return Result(text: text, isFinal: !text.isEmpty)
    }
}
