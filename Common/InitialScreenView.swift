//
//  InitialScreen.swift
//  ARSurgery
//
//  Created by Barath Balamurugan on 05/11/25.
//

import SwiftUI

struct InitialScreenView: View{
    @Environment(AppModel.self) var appModel
    @State private var status = "Idle"
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    var body: some View {
        VStack(spacing: 24) {
            Text("AR Surgery")
                .font(.largeTitle)
                .bold()
            Text(status)
                .font(.title3)
                .opacity(0.8)
            Button {
                Task {
                    if appModel.isImmersed {
                        // Close first, then flip the flag
                        await closeSpace()
                        appModel.isImmersed = false
                        dismissWindow(id: "personal-panel")
                    } else {
                        // Open first, then flip the flag
                        await openSpace()
                        appModel.isImmersed = true
                        openWindow(id: "personal-panel")
                    }
                }
            } label: {
                Label(appModel.isImmersed ? "Close Immersive Space" : "Open Immersive Space",
                      systemImage: appModel.isImmersed ? "xmark.circle.fill" : "sparkles")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
    
}
