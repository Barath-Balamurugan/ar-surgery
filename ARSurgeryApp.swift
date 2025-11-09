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
    
    var body: some Scene {
        WindowGroup(id: "main_screen") {
            MainScreen(
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
