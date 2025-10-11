//
//  Physics.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 23/09/2025.
//

import Foundation
import simd

public typealias Vec3 = SIMD3<Double>

@inlinable public func lengthSquared(_ v: Vec3) -> Double { dot(v, v) }

public final class NewtonianParticle: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var mass: Double
    public var position: Vec3
    public var velocity: Vec3
    
    public init(name: String,
                mass: Double,
                position: Vec3,
                velocity: Vec3,
                id: UUID = UUID()) {
        precondition(mass > 0, "Mass must be positive")
        self.id = id
        self.name = name
        self.mass = mass
        self.position = position
        self.velocity = velocity
    }
    
    public static func == (lhs: NewtonianParticle, rhs: NewtonianParticle) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct SystemSnapshot {
    public let t: Double
    public let positions: [UUID: Vec3]
    public let velocities: [UUID: Vec3]
}

public typealias ForceLaw = (_ i: Int, _ particles: [NewtonianParticle]) -> Vec3


public struct NewtonianGravity {
    public var G: Double
    public var softening: Double
    
    public init(G: Double = 6.6730e-11, softening: Double = 0.0) {
        self.G = G
        self.softening = max(0.0, softening)
    }
    
    public func asForceLaw() -> ForceLaw {
        let G = self.G
        let eps2 = softening * softening
        return { (i, particles) -> Vec3 in
            let pi = particles[i]
            var F = Vec3.zero
            let xi = pi.position
            for (j, pj) in particles.enumerated() where j != i {
                let r = pj.position - xi
                let r2 = lengthSquared(r) + eps2
                if r2 == 0 { continue }
                let invR = 1.0 / sqrt(r2)
                let invR3 = invR * invR * invR
                let scalar = (G * pi.mass * pj.mass) * invR3
                F += r * scalar
            }
            return F
        }
    }
}

public enum Integrator {
    case velocityVerlet
}

public final class PhysicsEngine {
    public private(set) var t: Double = 0.0
    public var particles: [NewtonianParticle]
    public var laws: [ForceLaw]
    public var integrator: Integrator = .velocityVerlet
    
    public init(particles: [NewtonianParticle], laws: [ForceLaw], integrator: Integrator = .velocityVerlet) {
        precondition(!particles.isEmpty, "Engine requires at least one particle.")
        self.particles = particles
        self.laws = laws
        self.integrator = integrator
    }
    
    @discardableResult
    public func step(dt: Double) -> SystemSnapshot {
        precondition(dt > 0, "dt must be positive")
        switch integrator {
        case.velocityVerlet:
            velocityVerletStep(dt: dt)
        }
        t += dt
        return snapshot()
    }
    
    public func energy(assuming gravity: NewtonianGravity?) -> (kinetic: Double, potential: Double, total: Double) {
        var K: Double = 0
        for p in particles {
            K += 0.5 * p.mass * lengthSquared(p.velocity)
        }
        
        var U: Double = 0
        if let g = gravity {
            let G = g.G
            let eps2 = g.softening * g.softening
            for i in 0..<particles.count {
                for j in (i + 1)..<particles.count {
                    let pi = particles[i]
                    let pj = particles[j]
                    let r = length(pj.position - pi.position)
                    let denom = sqrt(r * r + eps2)
                    if denom > 0 {
                        U -= G * pi.mass * pj.mass / denom
                    }
                }
            }
        }
        return (K, U, K + U)
    }
    
    private func netForces(for particles: [NewtonianParticle]) -> [Vec3] {
        var F = Array(repeating: Vec3.zero, count: particles.count)
        for i in particles.indices {
            var f = Vec3.zero
            for law in laws {
                f += law(i, particles)
            }
            F[i] = f
        }
        return F
    }
    
    private func velocityVerletStep(dt: Double) {
        let F_t = netForces(for: particles)
        var a_t = Array(repeating: Vec3.zero, count: particles.count)
        for i in particles.indices {
            a_t[i] = F_t[i] / particles[i].mass
        }
        
        let half_dt2 = 0.5 * dt * dt
        for i in particles.indices {
            let p = particles[i]
            p.position += p.velocity * dt + a_t[i] * half_dt2
        }
        
        let F_tdt = netForces(for: particles)
        var a_tdt = Array(repeating: Vec3.zero, count: particles.count)
        for i in particles.indices {
            a_tdt[i] = F_tdt[i] / particles[i].mass
        }
        
        let half_dt = 0.5 * dt
        for i in particles.indices {
            let p = particles[i]
            p.velocity += (a_t[i] + a_tdt[i]) * half_dt
        }
    }
    
    private func snapshot() -> SystemSnapshot {
        var positions: [UUID: Vec3] = [:]
        var velocities: [UUID: Vec3] = [:]
        for p in particles {
            positions[p.id] = p.position
            velocities[p.id] = p.velocity
        }
        
        return SystemSnapshot(t: t, positions: positions, velocities: velocities)
    }
}

public enum ThreeBodyFactory {
    public static func sunEarthMoonSystem(softening: Double = 0.0) -> (engine: PhysicsEngine, gravity: NewtonianGravity) {
        let mSun   = 1.98847e30
        let mEarth = 5.9722e24
        let mMoon  = 7.34767309e22
        
        // Distances (m)
        let AU: Double = 1.495978707e11
        let earthMoonDistance: Double = 384_400_000.0
        
        // Velocities (m/s) — circular-ish planar approximations
        let vEarth: Double = 29_780.0
        let vMoonRelative: Double = 1_022.0
        
        // Positions (put Sun at origin, Earth on +x axis, Moon offset from Earth)
        let sun = NewtonianParticle(
            name: "Sun",
            mass: mSun,
            position: Vec3(0, 0, 0),
            velocity: Vec3(0, 0, 0)
        )
        
        let earth = NewtonianParticle(
            name: "Earth",
            mass: mEarth,
            position: Vec3(AU, 0, 0),
            velocity: Vec3(0, vEarth, 0)
        )
        
        let moon = NewtonianParticle(
            name: "Moon",
            mass: mMoon,
            position: earth.position + Vec3(earthMoonDistance, 0, 0),
            velocity: earth.velocity + Vec3(0, vMoonRelative, 0)
        )
        
        let gravity = NewtonianGravity(softening: softening)
        let engine = PhysicsEngine(
            particles: [sun, earth, moon],
            laws: [gravity.asForceLaw()],
            integrator: .velocityVerlet
        )
        return (engine, gravity)
    }
}

public extension ThreeBodyFactory {
    static func randomThreeBodySystem(
        spaceExtent: Double = 1.0e9,
        massRange: ClosedRange<Double> = 1e22...1e26,
        speedRange: ClosedRange<Double> = 0.0...5.0e3,
        minSeparation: Double = 1.0e6,
        softening: Double = 0.0
    ) -> (engine: PhysicsEngine, gravity: NewtonianGravity) {
        var rng = SystemRandomNumberGenerator()
        return randomThreeBodySystem(
            spaceExtent: spaceExtent,
            massRange: massRange,
            speedRange: speedRange,
            minSeparation: minSeparation,
            softening: softening,
            rng: &rng
        )
    }
    
    static func randomThreeBodySystem<R: RandomNumberGenerator>(
        spaceExtent: Double,
        massRange: ClosedRange<Double>,
        speedRange: ClosedRange<Double>,
        minSeparation: Double,
        softening: Double,
        rng: inout R
    ) -> (engine: PhysicsEngine, gravity: NewtonianGravity) {
        precondition(spaceExtent > 0)
        precondition(massRange.lowerBound > 0 && massRange.lowerBound <= massRange.upperBound)
        precondition(speedRange.lowerBound >= 0 && speedRange.lowerBound <= speedRange.upperBound)
        precondition(minSeparation >= 0)
        
        // 1) Masses
        let m0 = Double.random(in: massRange, using: &rng)
        let m1 = Double.random(in: massRange, using: &rng)
        let m2 = Double.random(in: massRange, using: &rng)
        
        // 2) Positions with pairwise separation constraint
        let p0 = randomPosition(inCubeHalfExtent: spaceExtent, using: &rng)
        let p1 = randomPositionFar(from: [p0], minSeparation: minSeparation, inCubeHalfExtent: spaceExtent, using: &rng)
        let p2 = randomPositionFar(from: [p0, p1], minSeparation: minSeparation, inCubeHalfExtent: spaceExtent, using: &rng)
        
        // 3) Velocities with random directions and bounded speeds
        let v0 = randomVelocity(speedRange: speedRange, using: &rng)
        let v1 = randomVelocity(speedRange: speedRange, using: &rng)
        let v2 = randomVelocity(speedRange: speedRange, using: &rng)
        
        // 4) Shift to zero COM position and zero total linear momentum
        let masses = [m0, m1, m2]
        let pos = [p0, p1, p2]
        let vel = [v0, v1, v2]
        
        let mTot = masses.reduce(0, +)
        let rCOM = pos.enumerated().reduce(Vec3.zero) { acc, e in
            acc + (pos[e.offset] * masses[e.offset])
        } / mTot
        let pTot = vel.enumerated().reduce(Vec3.zero) { acc, e in
            acc + (vel[e.offset] * masses[e.offset])
        }
        let vCOM = pTot / mTot
        
        let P0 = NewtonianParticle(
            name: "BodyA",
            mass: m0,
            position: p0 - rCOM,
            velocity: v0 - vCOM
        )
        let P1 = NewtonianParticle(
            name: "BodyB",
            mass: m1,
            position: p1 - rCOM,
            velocity: v1 - vCOM
        )
        let P2 = NewtonianParticle(
            name: "BodyC",
            mass: m2,
            position: p2 - rCOM,
            velocity: v2 - vCOM
        )
        
        let gravity = NewtonianGravity(softening: softening)
        let engine = PhysicsEngine(
            particles: [P0, P1, P2],
            laws: [gravity.asForceLaw()],
            integrator: .velocityVerlet
        )
        return (engine, gravity)
    }
}

// MARK: - Private helpers

private func randomPosition<R: RandomNumberGenerator>(inCubeHalfExtent a: Double, using rng: inout R) -> Vec3 {
    let x = Double.random(in: -a...a, using: &rng)
    let y = Double.random(in: -a...a, using: &rng)
    let z = Double.random(in: -a...a, using: &rng)
    return Vec3(x, y, z)
}

private func randomUnitVector<R: RandomNumberGenerator>(using rng: inout R) -> Vec3 {
    // Marsaglia method
    while true {
        let x = Double.random(in: -1...1, using: &rng)
        let y = Double.random(in: -1...1, using: &rng)
        let s = x*x + y*y
        if s >= 1 || s == 0 { continue }
        let z = 1 - 2*s
        let f = 2 * sqrt(1 - s)
        return Vec3(x * f, y * f, z)
    }
}

private func randomVelocity<R: RandomNumberGenerator>(speedRange: ClosedRange<Double>, using rng: inout R) -> Vec3 {
    let dir = randomUnitVector(using: &rng)
    let speed = Double.random(in: speedRange, using: &rng)
    return dir * speed
}

private func randomPositionFar<R: RandomNumberGenerator>(
    from points: [Vec3],
    minSeparation: Double,
    inCubeHalfExtent a: Double,
    using rng: inout R
) -> Vec3 {
    guard minSeparation > 0 else {
        return randomPosition(inCubeHalfExtent: a, using: &rng)
    }
    let minSep2 = minSeparation * minSeparation
    let maxTries = 10_000
    for _ in 0..<maxTries {
        let p = randomPosition(inCubeHalfExtent: a, using: &rng)
        var ok = true
        for q in points {
            if lengthSquared(p - q) < minSep2 {
                ok = false
                break
            }
        }
        if ok { return p }
    }
    // Fallback: pick the farthest candidate among a batch if strict satisfaction failed.
    var bestP = randomPosition(inCubeHalfExtent: a, using: &rng)
    var bestMinD2 = 0.0
    for _ in 0..<1024 {
        let p = randomPosition(inCubeHalfExtent: a, using: &rng)
        let d2 = points.map { lengthSquared(p - $0) }.min() ?? .infinity
        if d2 > bestMinD2 {
            bestMinD2 = d2
            bestP = p
        }
    }
    return bestP
}
