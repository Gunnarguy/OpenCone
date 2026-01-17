import AVFoundation
import Speech
import SwiftUI

/// Service for handling voice input using iOS Speech Recognition
@MainActor
final class SpeechRecognitionService: ObservableObject {
    // MARK: - Published State

    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var error: String?
    @Published var audioLevel: Float = 0.0
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var levelTimer: Timer?

    // MARK: - Initialization

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized
    }

    /// Whether the button can trigger a listening session.
    /// Returns true if:
    /// - Authorization is either granted OR not yet determined (to allow first-tap prompt)
    /// - Not currently listening
    /// - Speech recognizer is available
    var canStartListening: Bool {
        let authOK = authorizationStatus == .authorized || authorizationStatus == .notDetermined
        return authOK && !isListening && (speechRecognizer?.isAvailable ?? false)
    }

    // MARK: - Recording Control

    func startListening() async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            if !authorized {
                throw SpeechError.notAuthorized
            }
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.notAvailable
        }

        // Stop any existing session
        stopListening()

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Allow cloud for better accuracy

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    // Don't treat cancellation as an error
                    if (error as NSError).code != 216 { // Cancelled error code
                        self.error = error.localizedDescription
                    }
                    self.stopListening()
                    return
                }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString

                    // Auto-stop on final result
                    if result.isFinal {
                        self.stopListening()
                    }
                }
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visual feedback
            let level = self?.calculateAudioLevel(buffer: buffer) ?? 0
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        error = nil
        transcribedText = ""

        // Start level monitoring
        startLevelMonitoring()
    }

    func stopListening() {
        levelTimer?.invalidate()
        levelTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        audioLevel = 0.0

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func toggleListening() async {
        if isListening {
            stopListening()
        } else {
            do {
                try await startListening()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Audio Level Calculation

    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }

        let frames = buffer.frameLength
        var sum: Float = 0

        for i in 0 ..< Int(frames) {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frames)
        // Normalize to 0-1 range with some amplification
        return min(average * 5, 1.0)
    }

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Level is updated in the audio tap
            _ = self
        }
    }

    // MARK: - Errors

    enum SpeechError: LocalizedError {
        case notAuthorized
        case notAvailable
        case requestCreationFailed
        case audioEngineError

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition not authorized. Please enable in Settings."
            case .notAvailable:
                return "Speech recognition is not available on this device."
            case .requestCreationFailed:
                return "Failed to create speech recognition request."
            case .audioEngineError:
                return "Failed to start audio engine."
            }
        }
    }
}

// MARK: - Voice Input Button View

struct VoiceInputButton: View {
    @ObservedObject var speechService: SpeechRecognitionService
    let onTranscription: (String) -> Void

    @Environment(\.theme) private var theme
    @State private var pulseAnimation = false

    var body: some View {
        Button {
            Task {
                if speechService.isListening {
                    speechService.stopListening()
                    // Send transcribed text
                    let text = speechService.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        Haptics.success()
                        onTranscription(text)
                    }
                } else {
                    Haptics.light()
                    await speechService.toggleListening()
                }
            }
        } label: {
            ZStack {
                // Pulsing background when listening
                if speechService.isListening {
                    Circle()
                        .fill(theme.primaryColor.opacity(0.2))
                        .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)

                    // Audio level indicator
                    Circle()
                        .fill(theme.primaryColor.opacity(0.3))
                        .scaleEffect(1.0 + CGFloat(speechService.audioLevel) * 0.5)
                }

                // Main button
                Image(systemName: speechService.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(speechService.isListening ? .white : theme.textSecondaryColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(speechService.isListening ? theme.primaryColor : Color.clear)
                    )
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        // Only disable if authorization was explicitly denied
        .disabled(speechService.authorizationStatus == .denied ||
            (speechService.authorizationStatus == .restricted))
        .opacity(speechService.authorizationStatus == .denied ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: speechService.isListening) { _, listening in
            if !listening {
                pulseAnimation = false
                // Reset animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        pulseAnimation = true
                    }
                }
            }
        }
    }
}

// MARK: - Listening Overlay

struct ListeningOverlay: View {
    @ObservedObject var speechService: SpeechRecognitionService
    @Environment(\.theme) private var theme

    var body: some View {
        if speechService.isListening {
            VStack(spacing: 12) {
                // Waveform visualization
                HStack(spacing: 3) {
                    ForEach(0 ..< 5, id: \.self) { index in
                        WaveformBar(level: speechService.audioLevel, index: index)
                    }
                }
                .frame(height: 30)

                Text(speechService.transcribedText.isEmpty ? "Listening..." : speechService.transcribedText)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimaryColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.cardBackgroundColor)
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Waveform Bar

private struct WaveformBar: View {
    let level: Float
    let index: Int
    @Environment(\.theme) private var theme

    @State private var animatedHeight: CGFloat = 0.2

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(theme.primaryColor)
            .frame(width: 4, height: max(4, animatedHeight * 30))
            .onChange(of: level) { _, newLevel in
                withAnimation(.easeInOut(duration: 0.1)) {
                    // Add some variation based on index
                    let variation = sin(Double(index) * 1.5) * 0.3 + 0.7
                    animatedHeight = CGFloat(newLevel) * CGFloat(variation)
                }
            }
    }
}
