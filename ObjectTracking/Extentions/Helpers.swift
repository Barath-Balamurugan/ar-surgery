import simd
import RealityKit

extension float4x4 {
    /// World translation (meters)
    var position: SIMD3<Float> {
        let t = columns.3
        return SIMD3<Float>(t.x, t.y, t.z)
    }

    /// World rotation as simd_quatf (uses RealityKit’s decomposition)
    var rotationQuat: simd_quatf {
        Transform(matrix: self).rotation
    }

    /// Euler XYZ in degrees (derived from quaternion)
    var eulerXYZDegrees: SIMD3<Float> {
        let q = rotationQuat
        let r = float3x3(q) // rotation matrix from quaternion
        let sy = sqrt(r[0,0]*r[0,0] + r[1,0]*r[1,0])
        let singular = sy < 1e-6

        let x: Float
        let y: Float
        let z: Float
        if !singular {
            x = atan2(r[2,1], r[2,2])
            y = atan2(-r[2,0], sy)
            z = atan2(r[1,0], r[0,0])
        } else {
            x = atan2(-r[1,2], r[1,1])
            y = atan2(-r[2,0], sy)
            z = 0
        }
        return SIMD3<Float>(x, y, z) * 180 / .pi
    }
}

