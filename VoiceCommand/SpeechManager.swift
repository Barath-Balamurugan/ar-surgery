//
//  SpeechManager.swift
//  ARSurgery
//
//  Created by Barath Balamurugan on 10/11/25.
//

import SwiftUI
import RealityKit
import AVFoundation
import Speech
import Combine

// MARK: - Speech manager

final class SpeechManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var lastTranscript: String = ""

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermissions() async throws {
        _ = try await AVAudioSession.sharedInstance().requestRecordPermission(<#(Bool) -> Void#>)
        let status = await SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let auth = await SFSpeechRecognizer.requestAuthorization(<#(SFSpeechRecognizerAuthorizationStatus) -> Void#>)
            if auth != .authorized { throw NSError(domain: "SpeechAuth", code: 1) }
        case .denied, .restricted:
            throw NSError(domain: "SpeechAuth", code: 2)
        @unknown default:
            throw NSError(domain: "SpeechAuth", code: 3)
        }
    }

    func start() throws {
        guard !audioEngine.isRunning else { return }
        lastTranscript = ""

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true

        guard let inputNode = audioEngine.inputNode else {
            throw NSError(domain: "Audio", code: 100, userInfo: [NSLocalizedDescriptionKey: "No input node"])
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer?.recognitionTask(with: request!) { [weak self] result, error in
            if let r = result {
                DispatchQueue.main.async { self?.lastTranscript = r.bestTranscription.formattedString }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self?.stop() }
            }
        }

        isListening = true
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
    }
}
