import Foundation
import Speech
import AVFoundation
import Combine

enum SpeechServiceError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineError
    case noTranscription

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in System Preferences."
        case .recognizerUnavailable:
            return "Speech recognizer is not available."
        case .audioEngineError:
            return "Failed to start audio engine."
        case .noTranscription:
            return "No transcription received."
        }
    }
}

final class SpeechService: ObservableObject {
    @Published private(set) var isListening: Bool = false
    @Published private(set) var currentTranscription: String = ""
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0

    var onTranscriptionComplete: ((String) -> Void)?

    init(locale: Locale = Locale(identifier: "pt-BR")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    // MARK: - Listening

    func startListening() async throws {
        print("🎤 Starting voice recognition...")
        print("🎤 Authorization status: \(authorizationStatus.rawValue)")

        guard authorizationStatus == .authorized else {
            print("🎤 ERROR: Not authorized")
            throw SpeechServiceError.notAuthorized
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("🎤 ERROR: Recognizer not available")
            throw SpeechServiceError.recognizerUnavailable
        }

        print("🎤 Recognizer locale: \(recognizer.locale.identifier)")

        // Stop any ongoing recognition
        stopListening()

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        // Try on-device first, fallback to server if not available
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest?.requiresOnDeviceRecognition = true
        } else {
            recognitionRequest?.requiresOnDeviceRecognition = false
            print("On-device recognition not available, using server")
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            throw SpeechServiceError.audioEngineError
        }

        await MainActor.run {
            isListening = true
            currentTranscription = ""
        }

        // Start recognition task
        print("🎤 Starting recognition task...")
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("🎤 Recognition error: \(error.localizedDescription)")
                self.stopListening()
                return
            }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                print("🎤 Transcription: \(transcription) (final: \(result.isFinal))")

                DispatchQueue.main.async {
                    self.currentTranscription = transcription
                    self.resetSilenceTimer()
                }

                if result.isFinal {
                    self.finishListening(with: transcription)
                }
            }
        }

        // Start silence timer
        resetSilenceTimer()
    }

    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        DispatchQueue.main.async { [weak self] in
            self?.isListening = false
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            let finalTranscription = self.currentTranscription
            if !finalTranscription.isEmpty {
                self.finishListening(with: finalTranscription)
            } else {
                self.stopListening()
            }
        }
    }

    private func finishListening(with transcription: String) {
        stopListening()

        DispatchQueue.main.async { [weak self] in
            self?.onTranscriptionComplete?(transcription)
        }
    }
}

// MARK: - Transcription Parsing
extension SpeechService {
    struct ParsedCommand {
        let projectName: String?
        let note: String?
    }

    func parseCommand(from transcription: String) -> ParsedCommand {
        let text = transcription.lowercased()

        // Common patterns:
        // "trabalhando no projeto Concepta"
        // "trabalhando em Concepta"
        // "projeto Concepta fazendo deploy"
        // "Concepta" (just project name)

        var projectName: String?
        var note: String?

        let projectPatterns = [
            "trabalhando no projeto ",
            "trabalhando em ",
            "trabalhando no ",
            "projeto ",
            "no projeto ",
            "em "
        ]

        for pattern in projectPatterns {
            if let range = text.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...])
                let words = afterPattern.split(separator: " ")

                if let firstWord = words.first {
                    projectName = String(firstWord)

                    // Rest is the note
                    if words.count > 1 {
                        note = words.dropFirst().joined(separator: " ")
                    }
                    break
                }
            }
        }

        // If no pattern matched, try to find project name in known projects
        if projectName == nil {
            let knownProjects = ["concepta", "atalho", "remot", "pessoal", "pesquisa", "whatsapp"]
            for project in knownProjects {
                if text.contains(project) {
                    projectName = project
                    // Everything else is the note
                    note = text.replacingOccurrences(of: project, with: "").trimmingCharacters(in: .whitespaces)
                    if note?.isEmpty == true { note = nil }
                    break
                }
            }
        }

        return ParsedCommand(projectName: projectName, note: note)
    }
}
