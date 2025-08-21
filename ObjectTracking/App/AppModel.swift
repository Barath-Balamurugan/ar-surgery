//
//  AppModel.swift
//  ObjectTracking
//
//  Created by Barath Balamurugan on 19/08/25.
//

import SwiftUI
import RealityKit

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    
    let spatialTrackingSession = SpatialTrackingSession()
}
