//
//  VoiceControllerSpatialView.swift
//  VoiceCommand
//
//  Created by Barath Balamurugan on 30/07/25.
//

import SwiftUI
import RealityKit
import Speech
import AVFoundation
import RealityKitContent

struct VoiceControlledSpatialView: View {
    @StateObject private var voiceManager = VoiceCommandManager()
    @StateObject private var modelManager = USDZModelManager()
    @State private var showInstructions = true
    
    var sceneName = "PhantomRawV4"
    
    var body: some View {
        ZStack {
            RealityView { content in
                if let existing = ModelStore.shared.phantom {
                    print("✅ Using existing model instance: \(sceneName)")
                    modelManager.setupModel(entity: existing)

                } else {
                    print("⚠️ No existing model named \(sceneName) found in ModelStore.")
                }
            }
            .onChange(of: voiceManager.lastCommand) { _, newCommand in
                if let command = newCommand {
                    modelManager.handleCommand(command)
                }
            }
            
            // UI Overlay
            VStack {
                // Voice indicator
                VoiceIndicatorView(voiceManager: voiceManager)
                    .padding()
                
                // Control buttons
                HStack(spacing: 20) {
                    Button(action: {
                        if voiceManager.isListening {
                            voiceManager.stopListening()
                        } else {
                            voiceManager.startListening()
                        }
                    }) {
                        Label(
                            voiceManager.isListening ? "Stop Listening" : "Start Listening",
                            systemImage: voiceManager.isListening ? "mic.slash.fill" : "mic.fill"
                        )
                        .padding()
                        .background(voiceManager.isListening ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        withAnimation {
                            showInstructions.toggle()
                        }
                    }) {
                        Label("Instructions", systemImage: "info.circle")
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
    }
}
