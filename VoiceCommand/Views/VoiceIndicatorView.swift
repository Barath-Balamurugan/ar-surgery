import SwiftUI
import RealityKit
import Speech
import AVFoundation

struct VoiceIndicatorView: View {
    @ObservedObject var voiceManager: VoiceCommandManager
    
    var body: some View {
        VStack(spacing: 10) {
            if voiceManager.commandExecuted {
                // Command executed feedback
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    
                    Text("Command Executed: \(voiceManager.executedCommandText)")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .cornerRadius(20)
                .transition(.scale.combined(with: .opacity))
            } else if voiceManager.isListening {
                // Wake state indicator
                if voiceManager.isAwake {
                    HStack {
                        Image(systemName: "ear.fill")
                            .symbolEffect(.pulse)
                            .foregroundStyle(.green)
                        
                        Text("Listening for commands...")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.green, lineWidth: voiceManager.wakeWordDetected ? 3 : 1)
                    )
                    .cornerRadius(20)
                    .scaleEffect(voiceManager.wakeWordDetected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: voiceManager.wakeWordDetected)
                } else {
                    // Sleep state indicator
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.blue)
                        
                        Text("Say 'Hey Probe' to activate")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                    .cornerRadius(20)
                }
                
                if !voiceManager.recognizedText.isEmpty &&
                   !voiceManager.recognizedText.contains("🟢") &&
                   !voiceManager.recognizedText.contains("💤") {
                    Text(voiceManager.recognizedText)
                        .font(.caption)
                        .padding()
                        .background(.thinMaterial)
                        .cornerRadius(10)
                        .frame(maxWidth: 300)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: voiceManager.commandExecuted)
        .animation(.easeInOut(duration: 0.3), value: voiceManager.isAwake)
    }
}
