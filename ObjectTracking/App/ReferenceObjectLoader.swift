//
//  ReferenceObjectLoader.swift
//  ObjectTracking
//
//  Created by Barath Balamurugan on 20/08/25.
//

import ARKit
import RealityKit

@MainActor
@Observable
final class ReferenceObjectLoader {
    private(set) var referenceObjects = [ReferenceObject]()
    var enabledReferenceObjects = [ReferenceObject]()
    var enabledReferenceObjectsCount: Int { enabledReferenceObjects.count }
    private(set) var usdzsPerReferenceObjectID = [UUID: Entity]()
    
    private var didStartLoading = false
    
    private var fileCount: Int = 0
    private var filesLoaded: Int = 0
    private(set) var progress: Float = 1.0
    
    private func finishedOneFile() {
        filesLoaded += 1
        updateProgress()
    }
    
    private func updateProgress() {
        if fileCount == 0 {
            progress = 1.0
        } else if filesLoaded == fileCount {
            progress = 1.0
        } else {
            progress = Float(filesLoaded) / Float(fileCount)
        }
    }
    
    func loadBuiltInReferenceObjects() async {
        guard !didStartLoading else {return}
        didStartLoading.toggle()
        
        print("Looking for reference objects in the main bundle ...")
        
        var referenceObjectFiles: [String] = []
        if let resourcesPath = Bundle.main.resourcePath {
            try? referenceObjectFiles = FileManager.default.contentsOfDirectory(atPath: resourcesPath).filter { $0.hasSuffix(".referenceobject")}
        }
        
        fileCount = referenceObjectFiles.count
        updateProgress()
        
        await withTaskGroup(of: Void.self) { group in
            for file in referenceObjectFiles {
                let objectURL = Bundle.main.bundleURL.appending(path: file)
                group.addTask{
                    await self.loadReferenceObject(objectURL)
                    await self.finishedOneFile()
                }
            }
        }
    }
    
    private func loadReferenceObject(_ url: URL) async {
        var referenceObject: ReferenceObject
        do {
            print("Loading reference object from \(url)")
            try await referenceObject = ReferenceObject(from: url)
        } catch {
            fatalError("Failed to load reference object with error \(error)")
        }
        
        referenceObjects.append(referenceObject)
        
        enabledReferenceObjects.append(referenceObject)
        
        if let usdzPath = referenceObject.usdzFile {
            var entity: Entity? = nil
            
            do{
                try await entity = Entity(contentsOf: usdzPath)
            } catch {
                print("Failed to load model \(usdzPath.absoluteString)")
            }
            
            usdzsPerReferenceObjectID[referenceObject.id] = entity
        }
    }
}
