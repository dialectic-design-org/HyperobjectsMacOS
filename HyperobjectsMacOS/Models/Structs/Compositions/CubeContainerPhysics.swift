//
//  CubeContainerPhysics.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 16/01/2026.
//

import simd

struct RigidBodyCube {
    var center: SIMD3<Float>
    var orientation: simd_quatf
    var halfExtents: SIMD3<Float>
    
    var velocity: SIMD3<Float> = .zero
    var angularVelocity: SIMD3<Float> = .zero
    
    var mass: Float = 1.0
    
    var inertialTensorBody: SIMD3<Float> {
        let m = mass
        let ex = halfExtents.x * 2
        let ey = halfExtents.y * 2
        let ez = halfExtents.z * 2
        let yz = (ey * ey + ez * ez)
        let xz = (ex * ex + ez * ez)
        let xy = (ex * ex + ey * ey)
        return SIMD3<Float>(
            (1.0 / 12.0) * m * yz,
            (1.0 / 12.0) * m * xz,
            (1.0 / 12.0) * m * xy
        )
    }
    
    var inverseInertiaTensorBody: SIMD3<Float> {
        let I = inertialTensorBody
        return SIMD3<Float>(1.0 / I.x, 1.0 / I.y, 1.0 / I.z)
    }
    
    func worldVertices() -> [SIMD3<Float>] {
        let rotationMatrix = simd_matrix3x3(orientation)
        var vertices: [SIMD3<Float>] = []
        for x in [-1.0, 1.0] as [Float] {
            for y in [-1.0, 1.0] as [Float] {
                for z in [-1.0, 1.0] as [Float] {
                    let localVertex = SIMD3<Float>(
                        x * halfExtents.x,
                        y * halfExtents.y,
                        z * halfExtents.z
                    )
                    let worldVertex = center + rotationMatrix * localVertex
                    vertices.append(worldVertex)
                }
            }
        }
        return vertices
    }
    
    func worldToLocal(_ worldPoint: SIMD3<Float>) -> SIMD3<Float> {
        let relativePosition = worldPoint - center
        let inverseRotation = orientation.conjugate
        return simd_act(inverseRotation, relativePosition)
    }
    
    func localToWorld(_ localPoint: SIMD3<Float>) -> SIMD3<Float> {
        return center + simd_act(orientation, localPoint)
    }
    
    func worldToLocalDirection(_ worldDir: SIMD3<Float>) -> SIMD3<Float> {
        return simd_act(orientation.conjugate, worldDir)
    }
    
    func localToWorldDirection(_ localDir: SIMD3<Float>) -> SIMD3<Float> {
        return simd_act(orientation, localDir)
    }
    
    var eulerAngles: SIMD3<Float> {
        return quaternionToEuler(orientation)
    }
    
    mutating func setEulerAngles(_ angles: SIMD3<Float>) {
        orientation = eulerToQuaternion(angles)
    }
}


struct KinematicCube {
    var center: SIMD3<Float>
    var orientation: simd_quatf
    var halfExtents: SIMD3<Float>
    
    func worldToLocal(_ worldPoint: SIMD3<Float>) -> SIMD3<Float> {
        let relativePosition = worldPoint - center
        return simd_act(orientation.conjugate, relativePosition)
    }
    
    func localToWorld(_ localPoint: SIMD3<Float>) -> SIMD3<Float> {
        return center + simd_act(orientation, localPoint)
    }
    
    func localToWorldDirection(_ localDir: SIMD3<Float>) -> SIMD3<Float> {
        return simd_act(orientation, localDir)
    }
    
    var eulerAngles: SIMD3<Float> {
        return quaternionToEuler(orientation)
    }
    
    mutating func setEulerAngles(_ angles: SIMD3<Float>) {
        orientation = eulerToQuaternion(angles)
    }
}


struct ContactPoint {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var penetrationDepth: Float
}


final class CubePhysicsSimulator {
    
    var outerCube: KinematicCube
    var innerCube: RigidBodyCube
    
    var outerLinearVelocity: SIMD3<Float> = .zero
    var outerAngularVelocity: SIMD3<Float> = .zero

    var debugEnabled: Bool = false
    var debugContactEvery: Int = 60
    private var debugContactCounter: Int = 0
    
    var gravity: SIMD3<Float> = SIMD3<Float>(0, -9.81, 0)
    
    // Bouncy "Rubber" Settings
    var restitution: Float = 0.92      // High bounciness (0.0 - 1.0)
    var friction: Float = 0.15         // Low friction
    var linearDamping: Float = 0.1     // Air resistance (per second)
    var angularDamping: Float = 0.1    // Angular drag (per second)
    
    var substeps: Int = 8
    
    init(
        outerCubeCenter: SIMD3<Float>,
        outerCubeRotation: SIMD3<Float>,   // Euler angles in radians
        outerCubeSize: SIMD3<Float>,       // Full size (not half extents)
        innerCubeCenter: SIMD3<Float>,
        innerCubeRotation: SIMD3<Float>,   // Euler angles in radians
        innerCubeSize: SIMD3<Float>,       // Full size (not half extents)
        innerCubeMass: Float = 1.0
    ) {
        self.outerCube = KinematicCube(
            center: outerCubeCenter,
            orientation: eulerToQuaternion(outerCubeRotation),
            halfExtents: outerCubeSize * 0.5
        )
        
        self.innerCube = RigidBodyCube(
            center: innerCubeCenter,
            orientation: eulerToQuaternion(innerCubeRotation),
            halfExtents: innerCubeSize * 0.5,
            mass: innerCubeMass
        )
    }
    
    func setOuterCubeRotation(_ eulerAngles: SIMD3<Float>) {
        outerCube.orientation = eulerToQuaternion(eulerAngles)
        outerAngularVelocity = .zero
    }
    
    func setOuterCubeRotation(_ eulerAngles: SIMD3<Float>, deltaTime: Float) {
        let newOrientation = eulerToQuaternion(eulerAngles)
        outerAngularVelocity = computeAngularVelocity(previous: outerCube.orientation, current: newOrientation, deltaTime: deltaTime)
        outerCube.orientation = newOrientation
    }
    
    func setOuterCubeOrientation(_ orientation: simd_quatf) {
        outerCube.orientation = orientation
        outerAngularVelocity = .zero
    }
    
    func setOuterCubeOrientation(_ orientation: simd_quatf, deltaTime: Float) {
        outerAngularVelocity = computeAngularVelocity(previous: outerCube.orientation, current: orientation, deltaTime: deltaTime)
        outerCube.orientation = orientation
    }
    
    func setOuterCubeCenter(_ center: SIMD3<Float>) {
        outerCube.center = center
    }
    
    func applyImpulse(_ impulse: SIMD3<Float>) {
        innerCube.velocity += impulse / innerCube.mass
    }
    
    func applyImpulseAtPoint(_ impulse: SIMD3<Float>, worldPoint: SIMD3<Float>) {
        // Linear impulse
        innerCube.velocity += impulse / innerCube.mass
        
        // Angular impulse
        let r = worldPoint - innerCube.center
        let torqueImpulse = cross(r, impulse)
        let angularImpulse = computeAngularImpulse(torqueImpulse)
        innerCube.angularVelocity += angularImpulse
    }
    
    func applyTorqueImpulse(_ torqueImpulse: SIMD3<Float>) {
        let angularImpulse = computeAngularImpulse(torqueImpulse)
        innerCube.angularVelocity += angularImpulse
    }
    
    func tick(deltaTime: Float) {
        let dt = deltaTime / Float(substeps)
        
        for _ in 0..<substeps {
            substep(dt: dt)
        }
    }
    
    private func substep(dt: Float) {
        // 1. Apply gravity
        innerCube.velocity += gravity * dt
        
        // 2. Apply damping (Time-step dependent)
        // damping 0.1 means approx 10% loss per second
        let linFactor = max(0.0, 1.0 - linearDamping * dt)
        let angFactor = max(0.0, 1.0 - angularDamping * dt)
        
        innerCube.velocity *= linFactor
        innerCube.angularVelocity *= angFactor
        
        // 3. Integrate position
        innerCube.center += innerCube.velocity * dt
        
        // 4. Integrate orientation
        integrateOrientation(dt: dt)
        
        // 5. Detect and resolve collisions
        resolveCollisions()
    }
    
    private func integrateOrientation(dt: Float) {
        let omega = innerCube.angularVelocity
        let omegaMagnitude = length(omega)
        
        if omegaMagnitude > 1e-8 {
            let axis = omega / omegaMagnitude
            let angle = omegaMagnitude * dt
            let deltaQ = simd_quatf(angle: angle, axis: axis)
            innerCube.orientation = simd_normalize(deltaQ * innerCube.orientation)
        }
    }
    
    private func resolveCollisions() {
        let contacts = detectCollisions()
        
        for contact in contacts {
            resolveContact(contact)
        }
    }
    
    private func detectCollisions() -> [ContactPoint] {
        var contacts: [ContactPoint] = []
        var deepestContact: ContactPoint?
        
        // Get inner cube vertices in world space
        let innerVertices = innerCube.worldVertices()
        
        // Check each vertex against the outer cube's interior
        for vertex in innerVertices {
            // Transform vertex to outer cube's local space
            let localVertex = outerCube.worldToLocal(vertex)
            
            // Check if vertex is outside the container bounds
            // (inside the container means within -halfExtents to +halfExtents)
            let maxBounds = outerCube.halfExtents
            let minBounds = -outerCube.halfExtents
            
            var isColliding = false
            
            // Check each axis against bounds
            for axis in 0..<3 {
                if localVertex[axis] > maxBounds[axis] {
                    isColliding = true
                    let penetration = localVertex[axis] - maxBounds[axis]
                    var normal = SIMD3<Float>(0, 0, 0)
                    normal[axis] = -1.0  // Push back inside
                    let worldNormal = outerCube.localToWorldDirection(normal)
                    let contact = ContactPoint(
                        position: vertex,
                        normal: worldNormal,
                        penetrationDepth: penetration
                    )
                    if deepestContact == nil || penetration > deepestContact!.penetrationDepth {
                        deepestContact = contact
                    }
                } else if localVertex[axis] < minBounds[axis] {
                    isColliding = true
                    let penetration = minBounds[axis] - localVertex[axis]
                    var normal = SIMD3<Float>(0, 0, 0)
                    normal[axis] = 1.0  // Push back inside
                    let worldNormal = outerCube.localToWorldDirection(normal)
                    let contact = ContactPoint(
                        position: vertex,
                        normal: worldNormal,
                        penetrationDepth: penetration
                    )
                    if deepestContact == nil || penetration > deepestContact!.penetrationDepth {
                        deepestContact = contact
                    }
                }
            }
            
            if isColliding, let contact = deepestContact {
                contacts = [contact]
            }
        }
        
        return contacts
    }
    
    private func resolveContact(_ contact: ContactPoint) {
        let normal = contact.normal
        
        // Relative position from inner cube center to contact point
        let r = contact.position - innerCube.center
        
        // Velocity at contact point (relative to moving outer cube wall)
        let innerVelocityAtContact = innerCube.velocity + cross(innerCube.angularVelocity, r)
        let outerVelocityAtContact = outerLinearVelocity + cross(outerAngularVelocity, contact.position - outerCube.center)
        let relativeVelocity = innerVelocityAtContact - outerVelocityAtContact
        
        // Relative velocity along normal (negative means approaching)
        let vn = dot(relativeVelocity, normal)

        if debugEnabled {
            debugContactCounter += 1
            if debugContactEvery > 0 && debugContactCounter % debugContactEvery == 0 {
                print("CubeContact vn=\(vn) depth=\(contact.penetrationDepth) relV=\(relativeVelocity)")
            }
        }
        
        // Only resolve if objects are approaching
        if vn >= 0 {
            // Still need to resolve penetration (correction must push INWARDS, so we ADD the inward normal)
            innerCube.center += normal * contact.penetrationDepth * 0.2
            return
        }
        
        // Compute impulse magnitude using the impulse formula
        // j = -(1 + e) * vn / (1/m + (r × n) · (I^-1 · (r × n)))
        
        let rCrossN = cross(r, normal)
        let angularTerm = computeAngularImpulse(rCrossN)
        let angularContribution = dot(cross(angularTerm, r), normal)
        
        let effectiveMass = 1.0 / innerCube.mass + angularContribution
        let jn = -(1.0 + restitution) * vn / effectiveMass
        
        // Apply normal impulse
        let normalImpulse = jn * normal
        innerCube.velocity += normalImpulse / innerCube.mass
        innerCube.angularVelocity += computeAngularImpulse(cross(r, normalImpulse))
        
        // Friction impulse (tangential)
        let tangentialVelocity = relativeVelocity - vn * normal
        let tangentialSpeed = length(tangentialVelocity)
        
        if tangentialSpeed > 1e-6 {
            let tangent = tangentialVelocity / tangentialSpeed
            
            // Friction impulse magnitude (Coulomb friction)
            let jt = min(friction * jn, tangentialSpeed * innerCube.mass)
            
            let frictionImpulse = -jt * tangent
            innerCube.velocity += frictionImpulse / innerCube.mass
            innerCube.angularVelocity += computeAngularImpulse(cross(r, frictionImpulse))
        }
        
        // Position correction to resolve penetration (correction must push INWARDS, so we ADD the inward normal)
        innerCube.center += normal * contact.penetrationDepth * 0.2
    }
    
    private func computeAngularImpulse(_ torqueImpulse: SIMD3<Float>) -> SIMD3<Float> {
        // Transform to body space
        let bodyTorque = innerCube.worldToLocalDirection(torqueImpulse)
        
        // Apply inverse inertia tensor (diagonal in body space)
        let bodyAngularImpulse = bodyTorque * innerCube.inverseInertiaTensorBody
        
        // Transform back to world space
        return innerCube.localToWorldDirection(bodyAngularImpulse)
    }
    
    private func computeAngularVelocity(previous: simd_quatf, current: simd_quatf, deltaTime: Float) -> SIMD3<Float> {
        guard deltaTime > 0 else { return .zero }
        var delta = current * previous.conjugate
        if delta.real < 0 {
            delta = simd_quatf(ix: -delta.imag.x, iy: -delta.imag.y, iz: -delta.imag.z, r: -delta.real)
        }
        let clampedReal = max(-1.0 as Float, min(1.0 as Float, delta.real))
        let angle = 2.0 * acos(clampedReal)
        let sinHalf = sqrt(max(0.0 as Float, 1.0 - clampedReal * clampedReal))
        if sinHalf < 1e-6 || angle.isNaN {
            return .zero
        }
        let axis = delta.imag / sinHalf
        return axis * (angle / deltaTime)
    }
    
    func getInnerCubeState() -> (center: SIMD3<Float>, rotation: SIMD3<Float>, velocity: SIMD3<Float>, angularVelocity: SIMD3<Float>) {
        return (
            innerCube.center,
            innerCube.eulerAngles,
            innerCube.velocity,
            innerCube.angularVelocity
        )
    }
    
    func getOuterCubeState() -> (center: SIMD3<Float>, rotation: SIMD3<Float>) {
        return (outerCube.center, outerCube.eulerAngles)
    }
    
    func getInnerCubeVertices() -> [SIMD3<Float>] {
        return innerCube.worldVertices()
    }
    
    func getInnerCubeOrientation() -> simd_quatf {
        return innerCube.orientation
    }
    
    func getOuterCubeOrientation() -> simd_quatf {
        return outerCube.orientation
    }
}


func eulerToQuaternion(_ euler: SIMD3<Float>) -> simd_quatf {
    let cx = cos(euler.x * 0.5)
    let sx = sin(euler.x * 0.5)
    let cy = cos(euler.y * 0.5)
    let sy = sin(euler.y * 0.5)
    let cz = cos(euler.z * 0.5)
    let sz = sin(euler.z * 0.5)
    
    return simd_quatf(
        ix: sx * cy * cz - cx * sy * sz,
        iy: cx * sy * cz + sx * cy * sz,
        iz: cx * cy * sz - sx * sy * cz,
        r:  cx * cy * cz + sx * sy * sz
    )
}

func quaternionToEuler(_ q: simd_quatf) -> SIMD3<Float> {
    let sinr_cosp = 2.0 * (q.real * q.imag.x + q.imag.y * q.imag.z)
    let cosr_cosp = 1.0 - 2.0 * (q.imag.x * q.imag.x + q.imag.y * q.imag.y)
    let roll = atan2(sinr_cosp, cosr_cosp)
    
    let sinp = 2.0 * (q.real * q.imag.y - q.imag.z * q.imag.x)
    let pitch: Float
    if abs(sinp) >= 1.0 {
        pitch = copysign(Float.pi / 2.0, sinp)
    } else {
        pitch = asin(sinp)
    }
    
    let siny_cosp = 2.0 * (q.real * q.imag.z + q.imag.x * q.imag.y)
    let cosy_cosp = 1.0 - 2.0 * (q.imag.y * q.imag.y + q.imag.z * q.imag.z)
    let yaw = atan2(siny_cosp, cosy_cosp)
    
    return SIMD3<Float>(roll, pitch, yaw)
}

func simd_matrix3x3(_ q: simd_quatf) -> simd_float3x3 {
    let x = q.imag.x
    let y = q.imag.y
    let z = q.imag.z
    let w = q.real
    
    let x2 = x + x
    let y2 = y + y
    let z2 = z + z
    
    let xx2 = x * x2
    let xy2 = x * y2
    let xz2 = x * z2
    let yy2 = y * y2
    let yz2 = y * z2
    let zz2 = z * z2
    let wx2 = w * x2
    let wy2 = w * y2
    let wz2 = w * z2
    
    return simd_float3x3(
        SIMD3<Float>(1.0 - yy2 - zz2, xy2 + wz2, xz2 - wy2),
        SIMD3<Float>(xy2 - wz2, 1.0 - xx2 - zz2, yz2 + wx2),
        SIMD3<Float>(xz2 + wy2, yz2 - wx2, 1.0 - xx2 - yy2)
    )
}
