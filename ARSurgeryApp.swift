//
//  ARSurgeryApp.swift
//  ARSurgery
//
//  Created by Barath Balamurugan on 05/11/25.
//

import SwiftUI

private enum UIIdentifier {
    static let immersiveSpace = "Object Tracking"
}

@main
struct ARSurgeryApp: App {
    @State private var appState = AppState()
    @StateObject private var modelStore = ModelStore.shared
    @StateObject private var voiceManager = VoiceCommandManager()
    
    var body: some Scene {
        WindowGroup(id: "main_screen") {
            MainScreen(
                appState: appState,
                immersiveSpaceIdentifier: UIIdentifier.immersiveSpace
            )
            .environmentObject(voiceManager)
            .task{
                if appState.allRequiredProvidersAreSupported {
                    await appState.referenceObjectLoader.loadBuiltInReferenceObjects()
                }
            }
        }
        .windowStyle(.plain)
        
        ImmersiveSpace(id: UIIdentifier.immersiveSpace){
            ImmersiveView(appState: appState)
                .environmentObject(modelStore)
                .environmentObject(voiceManager)
        }
    }
    
    
}
