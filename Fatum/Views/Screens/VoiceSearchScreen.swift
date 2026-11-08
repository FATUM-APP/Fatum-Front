//
//  VoiceSearchScreen.swift
//  Fatum
//

import SwiftUI

/// Full-screen voice search, opened from the mic in `ExpandingSearchField`.
///
/// It starts listening as soon as it appears. While the user talks, the live
/// transcript floats above the mic and the glow at the bottom follows their voice.
/// When they stop talking (see `VoiceRecorder`), what they said is added to the
/// conversation as a bubble and the recording goes to `onAudioRecorded`.
///
/// For now only the user's side is shown: the backend's reply (text and audio)
/// will be added here once it exists.
struct VoiceSearchScreen: View {
    /// Receives each recorded turn. The receiver owns the file and should delete it once sent.
    var onAudioRecorded: (VoiceRecording) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var recorder = VoiceRecorder()
    @State private var messages: [VoiceMessage] = []
    @State private var recorderError: String? = nil

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// Average of the latest mic levels (0...1), smooth enough to drive the animations.
    private var voiceLevel: CGFloat {
        guard recorder.isRecording else { return 0 }
        let recent = recorder.levels.suffix(4)
        return recent.reduce(0, +) / CGFloat(max(recent.count, 1))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.brandSecondary
                .ignoresSafeArea()

            voiceGlow

            VStack(spacing: 0) {
                conversation
                controls
            }
        }
        .animation(.smooth, value: recorder.state)
        .sensoryFeedback(.start, trigger: recorder.isRecording) { _, isRecording in isRecording }
        .sensoryFeedback(.stop, trigger: recorder.isRecording) { wasRecording, _ in wasRecording }
        .task { startListening() }
        .onDisappear { recorder.cancel() }
        .alert(
            "Micrófono",
            isPresented: Binding(
                get: { recorderError != nil },
                set: { if !$0 { recorderError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(recorderError ?? "")
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: layout.internalSpacing) {
                if messages.isEmpty {
                    emptyState
                }

                ForEach(messages) { message in
                    MessageBubble(message: message)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.top, layout.padding)
            .screenPadding(.horizontal)
        }
        // Keeps the latest message in view as the conversation grows.
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: layout.internalSpacing) {
            Text("¿Qué servicio necesitas?")
                .fatumStyle(.header)
                .foregroundStyle(.text)

            Text("Dímelo con tus palabras, yo te escucho.")
                .fatumStyle(.body)
                .foregroundStyle(.text)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, layout.externalSpacing)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: layout.spacingMedium) {
            statusText

            ZStack {
                micButton

                HStack {
                    Spacer()
                    closeButton
                }
            }
        }
        .screenPadding(.horizontal)
        .screenPadding(.bottom)
    }

    /// The live transcript while talking, otherwise a short hint about what's happening.
    private var statusText: some View {
        Group {
            switch recorder.state {
            case .preparing:
                Text("Preparando micrófono…")
            case .recording where recorder.transcript.isEmpty:
                Text("Te escucho…")
            case .recording, .finishing:
                Text(recorder.transcript)
            case .idle:
                Text("Toca el micrófono para hablar")
            }
        }
        .fatumStyle(.subheader)
        .italic()
        .foregroundStyle(.text.opacity(recorder.transcript.isEmpty ? 0.6 : 0.9))
        .multilineTextAlignment(.center)
        // Long sentences keep the latest words visible.
        .lineLimit(3)
        .truncationMode(.head)
        .frame(maxWidth: .infinity, minHeight: 60)
        .contentTransition(.opacity)
        .animation(.easeOut(duration: 0.2), value: recorder.transcript)
    }

    /// Big glass mic: tapping it while listening sends right away, otherwise starts a new turn.
    private var micButton: some View {
        Button(action: toggleListening) {
            Image(systemName: recorder.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.text)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 84, height: 84)
                .glassEffect(
                    recorder.isRecording
                        ? .regular.tint(.brandPrimary.opacity(0.3)).interactive()
                        : .regular.interactive(),
                    in: .circle
                )
                // Grows a little with the user's voice.
                .scaleEffect(1 + voiceLevel * 0.15)
                .animation(.easeOut(duration: 0.12), value: voiceLevel)
        }
        .buttonStyle(.plain)
        .disabled(recorder.state == .preparing || recorder.state == .finishing)
        .accessibilityLabel(recorder.isRecording ? "Enviar ahora" : "Hablar")
    }

    private var closeButton: some View {
        Button {
            recorder.cancel()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.brandSecondary)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.tint(.text).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cerrar")
    }

    /// Soft gradient rising from the bottom edge. Brighter and taller while the user talks.
    private var voiceGlow: some View {
        VStack {
            Spacer()
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .thirdGradient.opacity(0.45), location: 0.45),
                    .init(color: .brandPrimary.opacity(0.6), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320 + voiceLevel * 120)
        }
        .ignoresSafeArea()
        .opacity(recorder.isRecording ? 1 : 0.4)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: voiceLevel)
        .accessibilityHidden(true)
    }

    // MARK: - Actions

    private func toggleListening() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            startListening()
        }
    }

    private func startListening() {
        guard recorder.state == .idle else { return }
        Task {
            do {
                try await recorder.start(onFinish: handleRecording)
            } catch {
                recorderError = error.localizedDescription
            }
        }
    }

    private func handleRecording(_ recording: VoiceRecording) {
        withAnimation(.smooth) {
            messages.append(VoiceMessage(text: recording.transcript))
        }
        onAudioRecorded(recording)
    }
}

// MARK: - Messages

/// One turn of the conversation. `text` is `nil` when the device couldn't transcribe it.
private struct VoiceMessage: Identifiable {
    let id = UUID()
    let text: String?
}

/// The user's turn, right-aligned like a chat bubble.
private struct MessageBubble: View {
    let message: VoiceMessage

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Group {
            if let text = message.text {
                Text(text)
            } else {
                Label("Mensaje de voz", systemImage: "waveform")
            }
        }
        .fatumStyle(.body)
        .foregroundStyle(.brandPrimary)
        .padding(layout.internalPadding)
        .background(.primaryContainer, in: RoundedRectangle(cornerRadius: 20))
        .frame(maxWidth: 300, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview {
    VoiceSearchScreen()
}
