import SwiftUI
import RealityKit
import Speech
import AVFoundation
import Combine

class VoiceCommandManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var recognizedText = ""
    @Published var isListening = false
    @Published var lastCommand: VoiceCommand?
    @Published var commandExecuted = false
    @Published var executedCommandText = ""
    @Published var isAwake = false  // New: tracks if trigger word was heard
    @Published var wakeWordDetected = false  // New: visual feedback for wake word
    
    // Trigger words to activate command listening
    let triggerWords = ["hey probe", "probe", "hey model", "model", "activate", "listen"]
    let sleepWords = ["stop", "sleep", "goodbye", "stop listening"]
    
    // Timer to auto-sleep after inactivity
    private var sleepTimer: Timer?
    
    // Define voice commands for object control
    struct VoiceCommand: Equatable {
        let type: CommandType
        let componentName: String?
        
        enum CommandType: Equatable {
            case enable
            case disable
            case toggle
            case show
            case hide
        }
    }
    
    // Component names for your USDZ model
    let componentNames = [
        "bone", "brain", "skin", "soft tissue",
        "temporalis", "tumors", "venous", "ventricles"
    ]
    
    func startListening() {
        // First check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    // Also request microphone permission
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        if granted {
                            DispatchQueue.main.async {
                                self.startRecognition()
                            }
                        } else {
                            print("Microphone permission denied")
                        }
                    }
                case .denied:
                    print("Speech recognition authorization denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Unknown authorization status")
                }
            }
        }
    }
    
    private func startRecognition() {
        // Cancel any ongoing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session with error handling
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Start recognition task with error handling
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                
                // Check for trigger/sleep words first
                self.checkForTriggerWords(result.bestTranscription.formattedString)
                
                // Only process commands if awake
                if self.isAwake {
                    self.processCommand(result.bestTranscription.formattedString)
                }
                
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopListening()
            }
        }
        
        // Configure audio input with error handling
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Remove any existing tap before installing new one
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            print("Audio engine failed to start: \(error)")
            stopListening()
        }
    }
    
    func stopListening() {
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // End audio for recognition request
        recognitionRequest?.endAudio()
        
        // Cancel recognition task
        recognitionTask?.cancel()
        
        // Remove tap
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func checkForTriggerWords(_ text: String) {
        let lowercased = text.lowercased()
        
        // Check for sleep words first (higher priority)
        for sleepWord in sleepWords {
            if lowercased.contains(sleepWord) {
                goToSleep()
                return
            }
        }
        
        // Check for wake/trigger words
        for trigger in triggerWords {
            if lowercased.contains(trigger) && !isAwake {
                wakeUp()
                return
            }
        }
    }
    
    private func wakeUp() {
        isAwake = true
        wakeWordDetected = true
        recognizedText = "🟢 Listening for commands..."
        
        // Visual feedback animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.wakeWordDetected = false
        }
        
        // Reset sleep timer
        resetSleepTimer()
        
        print("✅ Wake word detected - now listening for commands")
    }
    
    private func goToSleep() {
        isAwake = false
        recognizedText = "💤 Say '\(triggerWords.first ?? "hey probe")' to activate"
        sleepTimer?.invalidate()
        sleepTimer = nil
        
        print("😴 Going to sleep - waiting for wake word")
    }
    
    private func resetSleepTimer() {
        sleepTimer?.invalidate()
        
        // Auto-sleep after 30 seconds of inactivity
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.goToSleep()
        }
    }
    
    // Add this to the component name aliases
    let componentAliases: [String: String] = [
        "1": "Bone",
        "2": "Brain",
        "3": "Skin",
        "4": "Soft Tissue",
        "5": "Temporalis",
        "6": "Tumers",
        "7": "Venous",
        "8": "Ventricles",
        "first": "Bone",
        "second": "Brain",
        "third": "Skin",
        "fourth": "Soft Tissue",
        "fifth": "Temporalis",
        "sixth": "Tumers",
        "seventh": "Venous",
        "eighth": "Ventricles"
    ]
    
    private func processCommand(_ text: String) {
        let lowercased = text.lowercased()
        
        // Debug: Print what was heard
        print("🎤 Heard: '\(text)' (Awake: \(isAwake))")
        
        // Reset sleep timer on any command
        if isAwake {
            resetSleepTimer()
        }
        
        // Don't process if not awake
        guard isAwake else {
            print("😴 Ignoring command - not awake")
            return
        }
        
        // METHOD 1: Number-based commands (most reliable)
        for (alias, componentName) in componentAliases {
            if lowercased.contains("enable " + alias) ||
               lowercased.contains("show " + alias) ||
               lowercased.contains("enable number " + alias) ||
               lowercased.contains("show number " + alias) {
                lastCommand = VoiceCommand(type: .enable, componentName: componentName)
                resetAfterCommand()
                return
            }
            
            if lowercased.contains("disable " + alias) ||
               lowercased.contains("hide " + alias) ||
               lowercased.contains("disable number " + alias) ||
               lowercased.contains("hide number " + alias) {
                lastCommand = VoiceCommand(type: .disable, componentName: componentName)
                resetAfterCommand()
                return
            }
            
            if lowercased.contains("toggle " + alias) ||
               lowercased.contains("toggle number " + alias) {
                lastCommand = VoiceCommand(type: .toggle, componentName: componentName)
                resetAfterCommand()
                return
            }
        }
        
        // METHOD 2: Single letter commands (B for Bone, S for Skin, etc.)
        let letterCommands: [String: String] = [
            "b": "Bone",
            "be": "Bone",
            "bee": "Bone",
            "s": "Skin",
            "es": "Skin",
            "ess": "Skin",
            "t": "Temporalis",
            "tea": "Temporalis",
            "v": "Venous",
            "vee": "Venous",
            "we": "Venous"
        ]
        
        for (letter, componentName) in letterCommands {
            if lowercased.contains("enable " + letter + " ") ||
               lowercased.contains("show " + letter + " ") ||
               lowercased.endsWith("enable " + letter) ||
               lowercased.endsWith("show " + letter) {
                lastCommand = VoiceCommand(type: .enable, componentName: componentName)
                resetAfterCommand()
                return
            }
        }
        
        // METHOD 3: Fuzzy matching with Levenshtein distance
        let commands = extractCommandAndTarget(from: lowercased)
        if let (action, target) = commands {
            if let bestMatch = findBestComponentMatch(for: target) {
                let commandType: VoiceCommand.CommandType
                switch action {
                case "enable", "show":
                    commandType = .enable
                case "disable", "hide":
                    commandType = .disable
                case "toggle":
                    commandType = .toggle
                default:
                    return
                }
                
                lastCommand = VoiceCommand(type: commandType, componentName: bestMatch)
                resetAfterCommand()
                return
            }
        }
        
        // Original phonetic matching (kept as fallback)
        let components: [(phrases: [String], actual: String)] = [
            (["bone", "phone", "blown", "bown", "bones"], "Bone"),
            (["brain", "brane", "brains"], "Brain"),
            (["skin", "screen", "scan", "skins", "scans"], "Skin"),
            (["soft tissue", "soft tissues", "soft", "sauce tissue", "softer shoe"], "Soft Tissue"),
            (["temporalis", "temporal", "temporary", "tempura"], "Temporalis"),
            (["tumors", "tumor", "tumers", "tumer", "rumors", "tremors"], "Tumers"),
            (["venous", "venus", "venis", "veinous", "veins"], "Venous"),
            (["ventricles", "ventricle", "ventrical", "ventriculs"], "Ventricles")
        ]
        
        // Check each component with all its variations
        for (phrases, actualName) in components {
            for phrase in phrases {
                if lowercased.contains("enable " + phrase) ||
                   lowercased.contains("show " + phrase) {
                    lastCommand = VoiceCommand(type: .enable, componentName: actualName)
                    resetAfterCommand()
                    return
                }
                
                if lowercased.contains("disable " + phrase) ||
                   lowercased.contains("hide " + phrase) {
                    lastCommand = VoiceCommand(type: .disable, componentName: actualName)
                    resetAfterCommand()
                    return
                }
                
                if lowercased.contains("toggle " + phrase) {
                    lastCommand = VoiceCommand(type: .toggle, componentName: actualName)
                    resetAfterCommand()
                    return
                }
            }
        }
        
        // Handle "all" commands
        let allPhrases = ["all", "everything", "all components", "all parts", "hall", "fall"]
        for phrase in allPhrases {
            if (lowercased.contains("show " + phrase) ||
                lowercased.contains("enable " + phrase)) {
                lastCommand = VoiceCommand(type: .enable, componentName: "all")
                resetAfterCommand()
                return
            }
            
            if (lowercased.contains("hide " + phrase) ||
                lowercased.contains("disable " + phrase)) {
                lastCommand = VoiceCommand(type: .disable, componentName: "all")
                resetAfterCommand()
                return
            }
        }
        
        print("❌ No command matched for: '\(text)'")
    }
    
    // Helper function to extract command and target
    private func extractCommandAndTarget(from text: String) -> (action: String, target: String)? {
        let actions = ["enable", "disable", "show", "hide", "toggle"]
        
        for action in actions {
            if let range = text.range(of: action + " ") {
                let afterAction = String(text[range.upperBound...])
                return (action, afterAction.trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
    
    // Find best matching component using fuzzy matching
    private func findBestComponentMatch(for input: String) -> String? {
        let components = ["Bone", "Brain", "Skin", "Soft Tissue", "Temporalis", "Tumers", "Venous", "Ventricles"]
        
        var bestMatch: String?
        var bestScore = Int.max
        
        for component in components {
            let score = levenshteinDistance(input.lowercased(), component.lowercased())
            if score < bestScore && score <= 3 { // Allow up to 3 character differences
                bestScore = score
                bestMatch = component
            }
        }
        
        return bestMatch
    }
    
    // Simple Levenshtein distance implementation
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)
        
        for (i, char1) in s1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                current[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        return last.last!
    }
    
    private func resetAfterCommand() {
        // Show command executed feedback
        commandExecuted = true
        executedCommandText = recognizedText
        
        // Clear the recognized text after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recognizedText = ""
            self?.commandExecuted = false
            self?.executedCommandText = ""
        }
        
        // Stop and restart listening for continuous operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.isListening {
                self.stopListening()
                // Restart listening after a brief pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.startListening()
                }
            }
        }
    }
}

extension String {
    func endsWith(_ suffix: String) -> Bool {
        return self.hasSuffix(suffix)
    }
}
