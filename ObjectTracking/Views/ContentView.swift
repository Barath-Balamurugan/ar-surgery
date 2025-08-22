//
//  ContentView.swift
//  ObjectTracking
//
//  Created by Barath Balamurugan on 19/08/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ContentView: View {
    @Bindable var appState: AppState
    let immersiveSpaceIdentifier: String
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var fileImporterIsOpen = false
    
    @StateObject private var voiceManager = VoiceCommandManager()
    
    var body: some View {
        VStack {
//            Model3D(named: "Scene", bundle: realityKitContentBundle)
//                .padding(.bottom, 50)

            Text("Hello, world!")
            
            VStack{
                VoiceIndicatorView(voiceManager: voiceManager)
                    .padding()
                
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
                }
                .padding()
            }
        }
        .padding()
        .toolbar{
            ToolbarItem(placement: .bottomOrnament) {
                if appState.canEnterImmersiveSpace{
                    VStack{
                        if !appState.isImmersiveSpaceOpened {
                            Button("Start Tracking \(appState.referenceObjectLoader.enabledReferenceObjectsCount) Object(s)") {
                                Task {
                                    switch await openImmersiveSpace(id: immersiveSpaceIdentifier) {
                                    case .opened:
                                        break
                                    case .error:
                                        print("An error occurred when trying to open the immersive space \(immersiveSpaceIdentifier)")
                                    case .userCancelled:
                                        print("The user declined opening immersive space \(immersiveSpaceIdentifier)")
                                    @unknown default:
                                        break
                                    }
                                }
                            }
                            .disabled(!appState.canEnterImmersiveSpace || appState.referenceObjectLoader.enabledReferenceObjectsCount == 0)
                        } else {
                            Button("Stop Tracking") {
                                Task{
                                    await dismissImmersiveSpace()
                                    appState.didLeaveImmersiveSpace()
                                }
                            }
                            if !appState.objectTrackingStartedRunning{
                                HStack {
                                    ProgressView()
                                    Text("Please wait until all reference objects have been loaded")
                                }
                            }
                        }
                        
                        Text(appState.isImmersiveSpaceOpened ? "This leaves the immersive space." : "This enters an immersive space, hiding all the other apps.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .onChange(of: scenePhase, initial: true) {
            print("HomeView scene phase: \(scenePhase)")
            if scenePhase == .active {
                Task {
                    // When returning from the background, check if the authorization has changed.
                    await appState.queryWorldSensingAuthorization()
                }
            } else {
                // Make sure to leave the immersive space if this view is no longer active
                // - such as when a person closes this view - otherwise they may be stuck
                // in the immersive space without the controls this view provides.
                if appState.isImmersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appState.didLeaveImmersiveSpace()
                    }
                }
            }
        }
        .onChange(of: appState.providersStoppedWithError, { _, providersStoppedWithError in
            // Immediately close the immersive space if an error occurs.
            if providersStoppedWithError {
                if appState.isImmersiveSpaceOpened {
                    Task {
                        await dismissImmersiveSpace()
                        appState.didLeaveImmersiveSpace()
                    }
                }
                
                appState.providersStoppedWithError = false
            }
        })
        .task {
            // Ask for authorization before a person attempts to open the immersive space.
            // This gives the app opportunity to respond gracefully if authorization isn't granted.
            if appState.allRequiredProvidersAreSupported {
                await appState.requestWorldSensingAuthorization()
            }
        }
        .task {
            // Start monitoring for changes in authorization, in case a person brings the
            // Settings app to the foreground and changes authorizations there.
            await appState.monitorSessionEvents()
        }
    }
}
