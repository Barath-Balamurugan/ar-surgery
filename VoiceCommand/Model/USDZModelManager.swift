import SwiftUI
import RealityKit
import Speech
import AVFoundation
import RealityKitContent

class USDZModelManager: ObservableObject {
    @Published var components: [String: ComponentInfo] = [:]
    @Published var modelLoaded = false
    var rootEntity: Entity?
    
    // Add this property to control animation behavior
    @Published var useAnimations = true
    
    struct ComponentInfo {
        let entity: Entity
        var isEnabled: Bool
        let originalTransform: Transform
    }
    
    func setupModel(entity: Entity) {
        rootEntity = entity
        findAndRegisterComponents(in: entity)
        modelLoaded = true
        print("Setup model with \(components.count) components")
    }
    
    private func findAndRegisterComponents(in entity: Entity, depth: Int = 0, parentName: String = "") {
        // Debug: Print entity hierarchy
        let indent = String(repeating: "  ", count: depth)
        print("\(indent)Entity: '\(entity.name.isEmpty ? "unnamed" : entity.name)' (children: \(entity.children.count))")
        
        // Expected component names - try different variations
        let expectedNames = ["Bone", "Brain", "Skin", "Soft Tissue", "SoftTissue", "Soft_Tissue",
                           "Temporalis", "Tumers", "Tumors", "Tumor",
                           "Venous", "Ventricles"]
        
        // Check current entity
        if !entity.name.isEmpty {
            // Try exact match
            if expectedNames.contains(entity.name) {
                registerComponent(entity, name: entity.name)
                print("✅ Registered component: '\(entity.name)'")
            }
            
            // Try case-insensitive match
            let lowercasedName = entity.name.lowercased()
            for expected in expectedNames {
                if lowercasedName == expected.lowercased() {
                    registerComponent(entity, name: expected)
                    print("✅ Registered component (case-insensitive): '\(expected)' for entity '\(entity.name)'")
                    break
                }
            }
            
            // Try partial match for multi-word components
            if lowercasedName.contains("soft") && lowercasedName.contains("tissue") {
                registerComponent(entity, name: "Soft Tissue")
                print("✅ Registered 'Soft Tissue' for entity '\(entity.name)'")
            }
            
            if lowercasedName.contains("tumor") {
                registerComponent(entity, name: "Tumers")
                print("✅ Registered 'Tumers' for entity '\(entity.name)'")
            }
        }
        
        // Process all children recursively
        for (index, child) in entity.children.enumerated() {
            print("\(indent)  Child \(index): '\(child.name)'")
            findAndRegisterComponents(in: child, depth: depth + 1, parentName: entity.name)
        }
        
        // Special handling: If this is the root and it has exactly 8 children, register them by index
        if depth == 0 && entity.children.count == 8 {
            print("\n📍 Found root with 8 children - registering by index as fallback")
            for (index, child) in entity.children.enumerated() {
                let componentName = "component\(index + 1)"
                registerComponent(child, name: componentName)
                print("  - Registered child \(index) as '\(componentName)' (actual name: '\(child.name)')")
            }
        }
        
        // Print summary when done with root
        if depth == 0 {
            print("\n📊 Component Registration Summary:")
            print("Total components registered: \(components.count)")
            let sortedComponents = components.keys.sorted()
            for name in sortedComponents {
                if let component = components[name] {
                    print("  - '\(name)' (entity name: '\(component.entity.name)')")
                }
            }
            
            // Check which expected components are missing
            print("\n🔍 Missing components check:")
            let registeredNames = Set(components.keys)
            for expected in ["Bone", "Brain", "Skin", "Soft Tissue", "Temporalis", "Tumers", "Venous", "Ventricles"] {
                if !registeredNames.contains(expected) {
                    print("  ❌ Missing: '\(expected)'")
                }
            }
            print("")
        }
    }
    
    func registerComponent(_ entity: Entity, name: String) {
        components[name] = ComponentInfo(
            entity: entity,
            isEnabled: true,
            originalTransform: entity.transform
        )
    }
    
    func enableComponent(named name: String) {
        guard let component = components[name] else {
            print("⚠️ Cannot enable - component '\(name)' not found")
            return
        }
        
        print("Enabling component: '\(name)'")
        
        // Cancel any pending disable operations
        component.entity.stopAllAnimations()
        
        // First ensure the entity is enabled
        component.entity.isEnabled = true
        
        // Reset to original transform immediately to ensure visibility
        component.entity.transform = component.originalTransform
        
        // Then animate from small to normal size
        component.entity.scale = [0.01, 0.01, 0.01]
        
        // Animate back to original scale
        var targetTransform = component.originalTransform
        
        component.entity.move(
            to: targetTransform,
            relativeTo: component.entity.parent,
            duration: 0.3,
            timingFunction: .easeOut
        )
        
        components[name]?.isEnabled = true
        
        // Double-check visibility after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if self.components[name]?.isEnabled == true {
                component.entity.isEnabled = true
                // Ensure scale is not zero
                if component.entity.scale.x < 0.1 {
                    component.entity.scale = component.originalTransform.scale
                }
            }
        }
    }
    
    func disableComponent(named name: String) {
        guard let component = components[name] else {
            print("⚠️ Cannot disable - component '\(name)' not found")
            return
        }
        
        print("Disabling component: '\(name)'")
        
        // Cancel any pending animations
        component.entity.stopAllAnimations()
        
        // Mark as disabled immediately
        components[name]?.isEnabled = false
        
        // Animate to tiny scale
        var targetTransform = component.entity.transform
        targetTransform.scale = [0.01, 0.01, 0.01]
        
        component.entity.move(
            to: targetTransform,
            relativeTo: component.entity.parent,
            duration: 0.3,
            timingFunction: .easeIn
        )
        
        // Disable visibility after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // Only disable if still marked as disabled (not re-enabled during animation)
            if self.components[name]?.isEnabled == false {
                component.entity.isEnabled = false
            }
        }
    }
    
    func toggleComponent(named name: String) {
        guard let component = components[name] else { return }
        
        if component.isEnabled {
            disableComponent(named: name)
        } else {
            enableComponent(named: name)
        }
    }
    
    // Alternative simple enable/disable without animations for reliability
    func simpleEnableComponent(named name: String) {
        guard let component = components[name] else { return }
        
        component.entity.isEnabled = true
        component.entity.transform = component.originalTransform
        components[name]?.isEnabled = true
        
        print("✅ Simple enabled: '\(name)'")
    }
    
    func simpleDisableComponent(named name: String) {
        guard let component = components[name] else { return }
        
        component.entity.isEnabled = false
        components[name]?.isEnabled = false
        
        print("✅ Simple disabled: '\(name)'")
    }
    
    func handleCommand(_ command: VoiceCommandManager.VoiceCommand) {
        guard let componentName = command.componentName else { return }
        
        print("\n🎤 Handling command: \(command.type) for '\(componentName)'")
        
        if componentName == "all" {
            // Handle all components
            print("Applying to all \(components.count) components")
            switch command.type {
            case .enable, .show:
                components.keys.forEach { enableComponent(named: $0) }
            case .disable, .hide:
                components.keys.forEach { disableComponent(named: $0) }
            case .toggle:
                components.keys.forEach { toggleComponent(named: $0) }
            }
        } else {
            // Handle specific component
            if components[componentName] != nil {
                print("✅ Found component '\(componentName)'")
                switch command.type {
                case .enable, .show:
                    enableComponent(named: componentName)
                case .disable, .hide:
                    disableComponent(named: componentName)
                case .toggle:
                    toggleComponent(named: componentName)
                }
            } else {
                print("❌ Component '\(componentName)' not found!")
                print("Available components: \(components.keys.sorted())")
            }
        }
    }
}
