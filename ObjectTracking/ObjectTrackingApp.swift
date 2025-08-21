//
//  ObjectTrackingApp.swift
//  ObjectTracking
//
//  Created by Barath Balamurugan on 19/08/25.
//

import SwiftUI

private enum UIIdentifier {
    static let immersiveSpace = "Object Tracking"
}

@main
@MainActor
struct ObjectTrackingApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(
                appState: appState,
                immersiveSpaceIdentifier: UIIdentifier.immersiveSpace
            )
            .task{
                if appState.allRequiredProvidersAreSupported {
                    await appState.referenceObjectLoader.loadBuiltInReferenceObjects()
                }
            }
        }
        .windowStyle(.plain)

        ImmersiveSpace(id: UIIdentifier.immersiveSpace){
            ImmersiveView(appState: appState)
        }
     }
}
