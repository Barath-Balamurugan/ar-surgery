//
//  ModelHub.swift
//  ARSurgery
//
//  Created by Barath Balamurugan on 08/11/25.
//

import SwiftUI
import RealityKit
import Combine

@MainActor
final class ModelStore: ObservableObject {
    static let shared = ModelStore()
    @Published var phantom: Entity?
    @Published var probe: Entity?
}
