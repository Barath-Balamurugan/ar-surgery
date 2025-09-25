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
import simd

struct ImmersiveView: View {
    var appState: AppState
    
    var root = Entity()
    @State private var objectVisualizations: [UUID: ObjectAnchorVisualization] = [:]
    
    @StateObject private var voiceManager = VoiceCommandManager()
    @StateObject private var modelManager = USDZModelManager()
    
    @State var worldFromPhantom: simd_float4x4 = matrix_identity_float4x4
    @State var worldFromProbe: simd_float4x4 = matrix_identity_float4x4
    @State var worldFromVirtualPhantom: simd_float4x4 = matrix_identity_float4x4
    @State var worldFromVirtualProbe: simd_float4x4 = matrix_identity_float4x4
    
    @State var virtualPhantomPos: simd_float4x4 = matrix_identity_float4x4
    
    @State var worldFromByRefName: [String: simd_float4x4] = [:]
    
    @State private var probeModel: Entity?
    @State private var phantomModel: Entity?
    @State private var phantomModelPivot: Entity?
    
    
    var body: some View
    {
        
        ZStack{
            RealityView{ content in
                content.add(root)
                
                Task{
                    let objectTracking = await appState.startTracking()
                    guard let objectTracking else {
                        return
                    }
                    
                    var modelCache = [String: Entity]()
                    func model(named name: String) async throws -> Entity {
                        if let cached = modelCache[name] { return await cached.clone(recursive: true) }
                        let loaded = try await Entity(named: name, in: realityKitContentBundle)
                        modelCache[name] = loaded
                        return await loaded.clone(recursive: true)
                    }
                    
                    for await anchorUpdates in objectTracking.anchorUpdates {
                        let anchor = anchorUpdates.anchor
                        let id = anchor.id
                        
                        if anchorUpdates.event == .updated || anchorUpdates.event == .added {
                            
                            if (anchor.referenceObject.name) == "PhantomRawV4" {
                                worldFromPhantom = anchor.originFromAnchorTransform
//                                printMatrix("worldFromPhantom", worldFromPhantom)
                                // Optional: also get position & orientation
//                                let t = SIMD3<Float>(worldFromPhantom.columns.3.x,
//                                                     worldFromPhantom.columns.3.y,
//                                                     worldFromPhantom.columns.3.z)
//                                let rot = simd_quatf(worldFromPhantom) // world ← phantom rotation
//                                print("Phantom pos (m):", t, " quat:", rot.vector)
                            }
                            else if (anchor.referenceObject.name) == "Probev5" {
                                worldFromProbe = anchor.originFromAnchorTransform
//                                printMatrix("worldFromPhantom", worldFromProbe)
                            }
                            
                            if let parent = phantomModel{
                                if let child = parent.findEntity(named: "VirtualPhantom") {
                                    phantomModelPivot = child
                                    virtualPhantomPos = child.transformMatrix(relativeTo: nil)
//                                    printMatrix("Value", virtualPhantomPos)
                                }
                                
                                let phantomFromProbe = relativeTransform(worldFromA: worldFromPhantom, worldFromB: worldFromProbe)
                                let virtualPhantomFromPhantom = simd_inverse(worldFromVirtualPhantom) * worldFromPhantom
                                let virtualPhantomFromVirtualProbe = virtualPhantomFromPhantom * phantomFromProbe * simd_inverse(virtualPhantomFromPhantom)
                                
                                worldFromVirtualProbe = virtualPhantomPos * phantomFromProbe
                                printMatrix("worldFromVirtualProbe", worldFromVirtualProbe)
                                try? await upsertProbe(
                                            localFromParent: virtualPhantomFromVirtualProbe,
                                            parent: phantomModelPivot!,
                                            realityKitContentBundle: realityKitContentBundle
                                        )
                            }
                            
                            let Fv_from_Offset = float4x4(translation: SIMD3<Float>(0, 0.32, -0.32))
                            
                            
                        }
                        
//                        print("Ref name:", anchor.referenceObject.name, "Ref ID:", anchor.referenceObject.id)
                        
                        switch anchorUpdates.event {
                            case .added:
                                let refName = anchor.referenceObject.name
                                
                                let modelName: String
                                switch refName{
                                    case "PhantomRawV4":
                                        modelName = "VirtualPhantomTracked"
                                    case "Probev5":
                                        modelName = "VirtualProbeTracked"
                                    default:
                                        modelName = "VirtualPhantomTracked"
                                }
                                
                                
                                let model = try await model(named: modelName)
                                let visualization = ObjectAnchorVisualization(for: anchor, withModel: model)
                                self.objectVisualizations[id] = visualization
                            
                                if refName == "PhantomRawV4"{
                                    root.addChild(visualization.entity)
                                    phantomModel = visualization.entity
                                }

                            case .updated:
                                objectVisualizations[id]?.update(with: anchor)
                                if anchor.referenceObject.name == "PhantomRawV4" {
                                    if let viz = objectVisualizations[anchor.id] {
                                        worldFromVirtualPhantom = viz.entity.transformMatrix(relativeTo: nil)
                                    }
                                }
                                
                            case .removed:
                                objectVisualizations[id]?.entity.removeFromParent()
                                objectVisualizations.removeValue(forKey: id)
                        }
                    }
                }
            }
            .onChange(of: voiceManager.lastCommand) { _, newCommand in
                if let command = newCommand {
                    modelManager.handleCommand(command)
                    voiceManager.lastCommand = nil
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
    
    func relativeTransform(worldFromA a: simd_float4x4,
                           worldFromB b: simd_float4x4) -> simd_float4x4 {
        // returns A_from_B (B relative to A)
        simd_inverse(a) * b
    }
    
    func printMatrix(_ label: String, _ m: simd_float4x4) {
        let c0 = m.columns.0, c1 = m.columns.1, c2 = m.columns.2, c3 = m.columns.3
        print("""
        \(label):
        [\(c0.x) \(c1.x) \(c2.x) \(c3.x)
         \(c0.y) \(c1.y) \(c2.y) \(c3.y)
         \(c0.z) \(c1.z) \(c2.z) \(c3.z)
         \(c0.w) \(c1.w) \(c2.w) \(c3.w)]
        """)
    }
    
    @MainActor
    func upsertProbe(localFromParent: simd_float4x4,
                     parent: Entity,
                     realityKitContentBundle: Bundle) async throws {
        if probeModel == nil {
            let m = try await Entity(named: "Probe_new", in: realityKitContentBundle)
            probeModel = m
            parent.addChild(m)
        } else if probeModel!.parent !== parent {
            parent.addChild(probeModel!)
        }
        // Set LOCAL pose (phantom ← probe)
        probeModel!.setTransformMatrix(localFromParent, relativeTo: parent)
    }

}

extension simd_float4x4 {
    init(translation t: SIMD3<Float>) {
        self = matrix_identity_float4x4
        self.columns.3 = SIMD4<Float>(t.x, t.y, t.z, 1)
    }

    static func fromEulerDegrees(rollX rx: Float, pitchY py: Float, yawZ yz: Float) -> simd_float4x4 {
        let r = rx * .pi / 180, p = py * .pi / 180, y = yz * .pi / 180
        let qz = simd_quatf(angle: y, axis: SIMD3<Float>(0,0,1))
        let qy = simd_quatf(angle: p, axis: SIMD3<Float>(0,1,0))
        let qx = simd_quatf(angle: r, axis: SIMD3<Float>(1,0,0))
        // Z * Y * X (yaw-pitch-roll)
        let q = qz * qy * qx
        return simd_float4x4(q)
    }
}
