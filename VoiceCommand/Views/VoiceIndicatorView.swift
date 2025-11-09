import SwiftUI

struct VoiceIndicatorView: View {
    @ObservedObject var voiceManager: VoiceCommandManager

    var body: some View {
        VStack(spacing: 10) {
            // Command executed toast
            if voiceManager.commandExecuted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Command executed: \(voiceManager.executedCommandText)")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(20)
                .transition(.scale.combined(with: .opacity))
            }

            // Listening indicator (no activation state)
            if voiceManager.isListening {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .symbolEffect(.variableColor) // harmless on platforms that support it
                        .foregroundStyle(.blue)
                    Text("Listening…")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .cornerRadius(20)

                // Live transcript (hide status emojis if you were adding any)
                if !voiceManager.recognizedText.isEmpty {
                    Text(voiceManager.recognizedText)
                        .font(.caption)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .frame(maxWidth: 320)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: voiceManager.commandExecuted)
        .animation(.easeInOut(duration: 0.25), value: voiceManager.isListening)
    }
}
