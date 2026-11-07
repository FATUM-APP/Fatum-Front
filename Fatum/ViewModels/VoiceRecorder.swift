//
//  VoiceRecorder.swift
//  Fatum
//

import AVFoundation
import Speech
import SwiftUI

/// The result of a voice search: the audio file to upload and, when the device
/// could transcribe it, the text the user said.
struct VoiceRecording {
    let fileURL: URL
    let transcript: String?
}

/// Records a voice note into an `.m4a` file and stops by itself when the user
/// stops talking, similar to Siri.
///
/// How it knows the user stopped:
/// - **With on-device transcription** (Apple's `SpeechTranscriber`, or
///   `DictationTranscriber` on older iPhones): the microphone audio is transcribed
///   live, and the recording ends when no new words arrive for `silenceAfterWords`.
///   Noise like traffic or a fan doesn't produce words, so it doesn't keep it going.
/// - **Fallback** (simulator, unsupported device, or the Spanish model isn't
///   downloaded yet): it compares the loudness to the room's background noise.
///
/// `onFinish` receives the file. The caller owns it from then on and should
/// delete it after sending it.
@MainActor
@Observable
final class VoiceRecorder {
    enum State: Equatable {
        case idle
        /// Asking for permission and setting up the microphone and transcriber.
        case preparing
        case recording
        /// Waiting a moment for the transcriber's final text before calling `onFinish`.
        case finishing
    }

    enum RecorderError: LocalizedError {
        case permissionDenied
        case couldNotStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Permite el acceso al micrófono en Ajustes para buscar con tu voz."
            case .couldNotStart:
                "No pudimos iniciar la grabación. Inténtalo de nuevo."
            }
        }
    }

    /// Number of samples kept for the live waveform.
    static let levelCount = 24

    private(set) var state: State = .idle
    /// Recent input levels normalized to 0...1, newest last. Drives the waveform.
    private(set) var levels: [CGFloat] = Array(repeating: 0, count: VoiceRecorder.levelCount)
    /// `true` once the user started talking (words were transcribed, or the voice
    /// was clearly louder than the room in fallback mode).
    private(set) var hasDetectedSpeech = false
    /// What the user has said so far. Empty when transcription isn't available.
    private(set) var transcript = ""

    // MARK: Tuning

    /// With transcription: how long without new words ends the recording.
    var silenceAfterWords: Duration = .seconds(1.3)
    /// Fallback: how much louder than the background noise (in dB) counts as speaking.
    var speechMargin: Float = 12
    /// Fallback: within this many dB of the background noise counts as silence.
    var silenceMargin: Float = 6
    /// Fallback: how long the user must stay quiet, after speaking, to end the recording.
    var silenceDuration: Duration = .seconds(1.5)
    /// Gives up (and discards) if nobody speaks for this long.
    var noSpeechTimeout: Duration = .seconds(8)
    /// Hard limit so a noisy room can't keep recording forever.
    var maxDuration: Duration = .seconds(60)

    var isRecording: Bool { state == .recording }

    private let engine = AVAudioEngine()
    private var tapProcessor: AudioTapProcessor?
    private var fileURL: URL?
    private var startedAt: ContinuousClock.Instant?
    private var onFinish: ((VoiceRecording) -> Void)?

    private var analyzer: SpeechAnalyzer?
    private var monitoringTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var lastWordAt: ContinuousClock.Instant?
    private let clock = ContinuousClock()

    // MARK: - Public API

    /// Downloads the Spanish speech model if it isn't on the device yet, so the
    /// first recording can already use it. Safe to call often; it's a no-op once installed.
    static func prepareSpeechModel() async {
        guard let transcriber = await Transcriber.make(),
              await AssetInventory.status(forModules: [transcriber.module]) != .installed,
              let request = try? await AssetInventory.assetInstallationRequest(supporting: [transcriber.module])
        else { return }
        try? await request.downloadAndInstall()
    }

    func start(onFinish: @escaping (VoiceRecording) -> Void) async throws {
        guard state == .idle else { return }
        state = .preparing

        guard await AVAudioApplication.requestRecordPermission() else {
            state = .idle
            throw RecorderError.permissionDenied
        }

        do {
            try await startEngine()
        } catch {
            stopEngine()
            transcriptionTask?.cancel()
            transcriptionTask = nil
            if let analyzer { Task { await analyzer.cancelAndFinishNow() } }
            analyzer = nil
            if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
            fileURL = nil
            state = .idle
            throw RecorderError.couldNotStart
        }

        self.onFinish = onFinish
        startedAt = clock.now
        state = .recording
        startMonitoring()
    }

    /// The user tapped stop: send whatever was recorded, unless it's too short to be useful.
    func stop() {
        let elapsed = startedAt.map { clock.now - $0 } ?? .zero
        finish(deliver: elapsed >= .milliseconds(500))
    }

    /// Discards the recording without calling `onFinish`.
    func cancel() {
        finish(deliver: false)
    }

    // MARK: - Setup

    private func startEngine() async throws {
        let session = AVAudioSession.sharedInstance()
        // `.measurement` turns off the automatic gain control, which otherwise
        // boosts the room's noise during pauses and hides the silence.
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.couldNotStart
        }

        // AAC in an .m4a: small files, accepted by every speech-to-text service.
        let url = FileManager.default.temporaryDirectory
            .appending(path: "voice-\(UUID().uuidString).m4a")
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: inputFormat.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        fileURL = url

        transcript = ""
        hasDetectedSpeech = false
        lastWordAt = nil
        levels = Array(repeating: 0, count: Self.levelCount)

        let (levelStream, levelContinuation) = AsyncStream.makeStream(of: Float.self)
        let speech = await startTranscription()

        let processor = AudioTapProcessor(
            file: file,
            inputFormat: inputFormat,
            analyzerFormat: speech?.format,
            analyzerInput: speech?.input,
            levels: levelContinuation
        )
        processor.install(on: input, format: inputFormat)
        tapProcessor = processor

        engine.prepare()
        try engine.start()
        monitoringLevels = levelStream
    }

    /// The level stream created in `startEngine`, consumed by `startMonitoring`.
    private var monitoringLevels: AsyncStream<Float>?

    /// Starts the on-device transcriber if the device supports it and the Spanish
    /// model is installed. Returns `nil` to use the loudness fallback instead.
    private func startTranscription() async -> (format: AVAudioFormat, input: AsyncStream<AnalyzerInput>.Continuation)? {
        guard let transcriber = await Transcriber.make() else { return nil }

        guard await AssetInventory.status(forModules: [transcriber.module]) == .installed else {
            // Not downloaded yet: use the fallback this time, have it ready for the next one.
            Task { await Self.prepareSpeechModel() }
            return nil
        }

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber.module]) else {
            return nil
        }

        let (inputStream, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let analyzer = SpeechAnalyzer(modules: [transcriber.module])
        do {
            try await analyzer.start(inputSequence: inputStream)
        } catch {
            inputContinuation.finish()
            return nil
        }
        self.analyzer = analyzer

        // Live results: finalized phrases are kept, the volatile (in-progress) one is replaced.
        transcriptionTask = Task { [weak self] in
            var finalized = ""
            do {
                for try await piece in transcriber.results {
                    guard let self else { return }
                    var volatile = ""
                    if piece.isFinal {
                        finalized += piece.text
                    } else {
                        volatile = piece.text
                    }
                    let text = (finalized + volatile).trimmingCharacters(in: .whitespacesAndNewlines)
                    if text != self.transcript {
                        self.transcript = text
                        self.lastWordAt = self.clock.now
                        if !text.isEmpty { self.hasDetectedSpeech = true }
                    }
                }
            } catch {
                // The transcriber failed mid-way; the loudness fallback keeps working.
                self?.analyzer = nil
            }
        }

        return (format, inputContinuation)
    }

    private func stopEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        tapProcessor?.finish()
        tapProcessor = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - End-of-speech detection

    /// Reads every audio level (about 10 per second) and decides when the user stopped talking.
    private func startMonitoring() {
        guard let levelStream = monitoringLevels else { return }
        monitoringLevels = nil

        monitoringTask = Task { [weak self] in
            var loudness = LoudnessDetector()
            var quietSince: ContinuousClock.Instant?

            for await power in levelStream {
                guard let self, let startedAt = self.startedAt else { return }
                self.appendLevel(power)

                let now = self.clock.now
                let elapsed = now - startedAt
                let reading = loudness.update(
                    power: power,
                    speechMargin: self.speechMargin,
                    silenceMargin: self.silenceMargin
                )

                if self.analyzer != nil {
                    // Transcription mode: stop when the words stop.
                    if let lastWordAt = self.lastWordAt, self.hasDetectedSpeech,
                       now - lastWordAt >= self.silenceAfterWords {
                        self.finish(deliver: true)
                        return
                    }
                } else {
                    // Fallback: stop when the loudness is back to the room's noise.
                    if reading.hasDetectedSpeech { self.hasDetectedSpeech = true }
                    if !reading.isSilent {
                        quietSince = nil
                    } else if self.hasDetectedSpeech {
                        let since = quietSince ?? now
                        quietSince = since
                        if now - since >= self.silenceDuration {
                            self.finish(deliver: true)
                            return
                        }
                    }
                }

                #if DEBUG
                loudness.logIfNeeded(transcript: self.analyzer != nil ? self.transcript : nil)
                #endif

                if !self.hasDetectedSpeech && elapsed >= self.noSpeechTimeout {
                    self.finish(deliver: false)
                    return
                }
                if elapsed >= self.maxDuration {
                    self.finish(deliver: true)
                    return
                }
            }
        }
    }

    /// Maps -60...0 dBFS to 0...1 for the waveform.
    private func appendLevel(_ power: Float) {
        let normalized = CGFloat(max(0, min(1, (power + 60) / 60)))
        levels.removeFirst()
        levels.append(normalized)
    }

    private func finish(deliver: Bool) {
        guard state == .recording, let fileURL else { return }

        monitoringTask?.cancel()
        monitoringTask = nil
        // Stopping the engine also ends the transcriber's audio input.
        stopEngine()

        let analyzer = self.analyzer
        let transcriptionTask = self.transcriptionTask
        let onFinish = self.onFinish
        self.analyzer = nil
        self.transcriptionTask = nil
        self.onFinish = nil
        self.fileURL = nil
        self.startedAt = nil
        levels = Array(repeating: 0, count: Self.levelCount)

        guard deliver else {
            state = .idle
            transcriptionTask?.cancel()
            Task { await analyzer?.cancelAndFinishNow() }
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        state = .finishing
        Task {
            if let analyzer, let transcriptionTask {
                // Lets the transcriber finalize the last words, but never waits more than 2 s.
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try? await analyzer.finalizeAndFinishThroughEndOfInput()
                        await transcriptionTask.value
                    }
                    group.addTask { try? await Task.sleep(for: .seconds(2)) }
                    await group.next()
                    group.cancelAll()
                }
            }
            let text = transcript
            state = .idle
            onFinish?(VoiceRecording(fileURL: fileURL, transcript: text.isEmpty ? nil : text))
        }
    }
}

// MARK: - Transcriber

/// Wraps whichever Apple transcriber this device supports, in Spanish.
private struct Transcriber {
    struct Piece {
        let text: String
        let isFinal: Bool
    }

    let module: any SpeechModule
    /// Creates the stream of results. Lazy so that just checking the model
    /// (in `prepareSpeechModel`) doesn't leave a listener running.
    private let makeResults: () -> AsyncThrowingStream<Piece, Error>

    var results: AsyncThrowingStream<Piece, Error> { makeResults() }

    /// Spanish variants to try, most preferred first.
    private static let locales = ["es-CO", "es-MX", "es-US", "es-ES"].map { Locale(identifier: $0) }

    /// `SpeechTranscriber` when supported (newer devices), otherwise `DictationTranscriber`.
    static func make() async -> Transcriber? {
        for wanted in locales {
            if let locale = await SpeechTranscriber.supportedLocale(equivalentTo: wanted) {
                let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
                return Transcriber(module: transcriber) {
                    stream(transcriber.results) { Piece(text: String($0.text.characters), isFinal: $0.isFinal) }
                }
            }
        }
        for wanted in locales {
            if let locale = await DictationTranscriber.supportedLocale(equivalentTo: wanted) {
                let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
                return Transcriber(module: transcriber) {
                    stream(transcriber.results) { Piece(text: String($0.text.characters), isFinal: $0.isFinal) }
                }
            }
        }
        return nil
    }

    private static func stream<S: AsyncSequence & Sendable>(
        _ results: S,
        transform: @escaping @Sendable (S.Element) -> Piece
    ) -> AsyncThrowingStream<Piece, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await result in results {
                        continuation.yield(transform(result))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Loudness fallback

/// Estimates the room's background noise and tells speech from silence by loudness.
/// The noise estimate follows quiet moments quickly and rises slowly, so it adapts to each room.
private struct LoudnessDetector {
    struct Reading {
        let hasDetectedSpeech: Bool
        let isSilent: Bool
    }

    private var smoothed: Float?
    private var noiseFloor: Float?
    private var peak: Float = -160
    private(set) var level: Float = -160
    #if DEBUG
    private var sampleCount = 0
    #endif

    mutating func update(power: Float, speechMargin: Float, silenceMargin: Float) -> Reading {
        // Light smoothing so a single loud or quiet sample doesn't decide anything.
        let level = smoothed.map { $0 * 0.6 + power * 0.4 } ?? power
        smoothed = level
        self.level = level

        var floor = noiseFloor ?? level
        if level < floor {
            floor += (level - floor) * 0.3
        } else if level < floor + speechMargin {
            floor += (level - floor) * 0.02
        }
        noiseFloor = floor
        peak = max(peak, level)

        // Uses the peak so speech right at the start (before the noise estimate
        // settles) still counts once the room goes quiet.
        return Reading(
            hasDetectedSpeech: peak - floor >= speechMargin,
            isSilent: level < floor + silenceMargin
        )
    }

    #if DEBUG
    mutating func logIfNeeded(transcript: String?) {
        sampleCount += 1
        guard sampleCount % 5 == 0 else { return }
        let mode = transcript.map { "words: \"\($0)\"" } ?? "loudness fallback"
        print(String(format: "🎙️ level %.1f dB | noise %.1f dB | ", level, noiseFloor ?? 0) + mode)
    }
    #endif
}

// MARK: - Audio thread

/// Runs on the audio thread for every microphone buffer: writes it to the file,
/// reports its level, and feeds a converted copy to the transcriber.
/// `nonisolated` because Core Audio calls the tap off the main thread.
nonisolated private final class AudioTapProcessor: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private let converter: AVAudioConverter?
    private let analyzerFormat: AVAudioFormat?
    private let analyzerInput: AsyncStream<AnalyzerInput>.Continuation?
    private let levels: AsyncStream<Float>.Continuation

    init(
        file: AVAudioFile,
        inputFormat: AVAudioFormat,
        analyzerFormat: AVAudioFormat?,
        analyzerInput: AsyncStream<AnalyzerInput>.Continuation?,
        levels: AsyncStream<Float>.Continuation
    ) {
        self.file = file
        self.analyzerFormat = analyzerFormat
        self.analyzerInput = analyzerInput
        self.levels = levels
        self.converter = analyzerFormat.flatMap { AVAudioConverter(from: inputFormat, to: $0) }
        // No priming, so converted audio stays aligned with the original.
        self.converter?.primeMethod = .none
    }

    func install(on node: AVAudioInputNode, format: AVAudioFormat) {
        node.installTap(onBus: 0, bufferSize: 2048, format: format) { [self] buffer, _ in
            process(buffer)
        }
    }

    func finish() {
        lock.lock()
        file = nil  // Releasing the file closes it and finalizes the .m4a.
        lock.unlock()
        levels.finish()
        analyzerInput?.finish()
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file else { return }

        try? file.write(from: buffer)
        levels.yield(Self.power(of: buffer))

        if let analyzerInput, let converted = convert(buffer) {
            analyzerInput.yield(AnalyzerInput(buffer: converted))
        }
    }

    /// Converts the mic's format (e.g. 48 kHz) to the one the transcriber expects.
    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter, let analyzerFormat else { return nil }
        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return nil }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status == .error || output.frameLength == 0 ? nil : output
    }

    /// Loudness of the buffer in dBFS (0 is the loudest, -160 is silence).
    private static func power(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -160 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(count)).squareRoot()
        return 20 * log10(max(rms, 0.000_000_1))
    }
}
