//
//  Arc.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 10/01/2026.
//

import simd

struct Arc3D {
    let origin: SIMD3<Float>
    let radius: Float
    let startTheta: Float
    let startPhi: Float
    let direction: Float
    let arcLength: Float
    var angularExtent: Float {
        arcLength / radius
    }
    
    var startPoint: SIMD3<Float> {
        origin + sphericalToLocalCartesian(theta: startTheta, phi: startPhi)
    }
    
    var endPoint: SIMD3<Float> {
        point(at: 1.0)
    }
    
    var startRadial: SIMD3<Float> {
        normalize(sphericalToLocalCartesian(theta: startTheta, phi: startPhi))
    }
    
    var startTangent: SIMD3<Float> {
        tangentDirection(theta: startTheta, phi: startPhi, direction: direction)
    }
    
    var arcNormal: SIMD3<Float> {
        normalize(cross(startRadial, startTangent))
    }
    
    var endTheta: Float {
        endSphericalCoordinates().theta
    }
    
    var endPhi: Float {
        endSphericalCoordinates().phi
    }
    
    var endDirection: Float {
        endSphericalCoordinates().direction
    }
    
    private func sphericalToLocalCartesian(theta: Float, phi: Float) -> SIMD3<Float> {
        SIMD3<Float>(
            radius * sin(phi) * cos(theta),
            radius * sin(phi) * sin(theta),
            radius * cos(phi)
        )
    }
    
    private func localTangentBasis(theta: Float, phi: Float) -> (thetaDir: SIMD3<Float>, phiDir: SIMD3<Float>) {
        let thetaDir = SIMD3<Float>(
            -sin(theta),
             cos(theta),
             0
        )
        
        let phiDir = SIMD3<Float>(
            cos(phi) * cos(theta),
            cos(phi) * sin(theta),
            -sin(phi)
        )
        
        return (normalize(thetaDir), normalize(phiDir))
    }
    
    private func tangentDirection(theta: Float, phi: Float, direction: Float) -> SIMD3<Float> {
        let basis = localTangentBasis(theta: theta, phi: phi)
        let tangent = -basis.phiDir * cos(direction) + basis.thetaDir * sin(direction)
        return normalize(tangent)
    }
    
    func point(at t: Float) -> SIMD3<Float> {
        let angle = t * angularExtent
        let radial = startRadial
        let tangent = startTangent
        
        let normal = arcNormal
        let rotatedRadial = radial * cos(angle) +
                            cross(normal, radial) * sin(angle) +
                            normal * dot(normal, radial) * (1 - cos(angle))
        
        return origin + rotatedRadial * radius
    }
    
    func tangent(at t: Float) -> SIMD3<Float> {
        let angle = t * angularExtent
        let normal = arcNormal
        
        let rotatedTangent = startTangent * cos(angle) +
                            cross(normal, startTangent) * sin(angle) +
                            normal * dot(normal, startTangent) * (1 - cos(angle))
        
        return normalize(rotatedTangent)
    }
    
    private func endSphericalCoordinates() -> (theta: Float, phi: Float, direction: Float) {
        let endPos = endPoint - origin
        let endTangent = tangent(at: 1.0)
        
        let r = length(endPos)
        let endPhi = acos(endPos.z / r)
        let endTheta = atan2(endPos.y, endPos.x)
        
        let basis = localTangentBasis(theta: endTheta, phi: endPhi)
        
        let northComponent = -dot(endTangent, basis.phiDir)
        let eastComponent = dot(endTangent, basis.thetaDir)
        let endDirection = atan2(eastComponent, northComponent)
        
        return (endTheta, endPhi, endDirection)
    }
    
    func sample(count: Int) -> [SIMD3<Float>] {
        guard count > 1 else { return [startPoint] }
        return (0..<count).map { i in
            point(at: Float(i) / Float(count - 1))
        }
    }
}


