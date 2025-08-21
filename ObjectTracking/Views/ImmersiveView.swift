//
//  ImmersiveView.swift
//  ObjectTracking
//
//  Created by Barath Balamurugan on 19/08/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    var appState: AppState
    
    var root = Entity()
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    
    var body: some View {
        RealityView{ content in
            content.add(root)
            
            Task{
                let objectTracking = await appState.startTracking()
                guard let objectTracking else {
                    return
                }
                
                for await anchorUpdates in objectTracking.anchorUpdates {
                    let anchor = anchorUpdates.anchor
                    let id = anchor.id
                    
                    switch anchorUpdates.event {
                    case .added:
                        let model = try await Entity(named: "Scene", in: realityKitContentBundle)
//                        let model = appState.referenceObjectLoader.usdzsPerReferenceObjectID[anchor.referenceObject.id]
                        let visualization = ObjectAnchorVisualization(for: anchor, withModel: model)
                        self.objectVisualizations[id] = visualization
                        root.addChild(visualization.entity)
                    case .updated:
                        objectVisualizations[id]?.update(with: anchor)
                    case .removed:
                        objectVisualizations[id]?.entity.removeFromParent()
                        objectVisualizations.removeValue(forKey: id)
                    }
                }
            }
        }
        .onAppear() {
            print ("Entering immersive view")
            appState.isImmersiveSpaceOpened = true
        }
        .onDisappear() {
            print ("Leaving immersive space.")
            
            for (_, visualization) in objectVisualizations {
                root.addChild(visualization.entity)
            }
            
            objectVisualizations.removeAll()
            appState.isImmersiveSpaceOpened = false
        }
    }
}


