//
//  CubeLetters.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 04/01/2026.
//

import Foundation
import simd
import Foundation
import simd

// MARK: - Style

struct CubeLetterStyle {
    // Layout
    var letterWidth: Float = 1.0
    var letterHeight: Float = 1.4
    var letterDepth: Float = 0.35
    var kerning: Float = 0.35
    var lineSpacing: Float = 0.8
    var maxLineWidth: Float = 0.0

    // Global scaling
    var worldScale: Float = 1.0

    // Base size + jitter
    var baseCubeSize: Float = 0.08
    var sizeJitter: Float = 0.85

    // NEW: prism shaping
    /// Typical axis scaling range; final axisScale sampled inside these bounds.
    /// (1,1,1) => cubes; larger ranges => rectangular prisms.
    var prismScaleMin: SIMD3<Float> = SIMD3<Float>(0.45, 0.45, 0.45)
    var prismScaleMax: SIMD3<Float> = SIMD3<Float>(2.2, 2.2, 2.2)

    /// Bias toward 1.0 (cube-like) vs extreme prisms.
    /// 0 => uniform in [min,max], 1 => strongly biased to 1.0, >1 even stronger.
    var prismCubeBias: Float = 0.75

    /// Correlation between cube size and elongation:
    /// 0 => independent, 1 => larger cubes tend to be more elongated.
    var prismSizeCorrelation: Float = 0.35

    // Distribution / “glyph” feel
    var cubesPerLetter: Int = 90
    var coherence: Float = 0.72
    var strokeCount: Int = 4
    var strokeSteps: Int = 22
    var strokeStep: Float = 0.06
    var driftToAnchors: Float = 0.35

    // Abstraction
    var jitterXY: Float = 0.05
    var jitterZ: Float = 1.0
    var rotationJitter: Float = 0.9
    var tiltPerLetter: SIMD3<Float> = SIMD3<Float>(0.0, 0.0, 0.25)

    // Whitespace
    var spaceAdvance: Float = 0.75
}

// MARK: - Deterministic RNG

struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextFloat01() -> Float {
        let v = nextUInt64() >> 40
        return Float(v) / Float(1 << 24)
    }

    mutating func nextSigned() -> Float { (nextFloat01() * 2.0) - 1.0 }

    mutating func nextInt(_ upperBoundExclusive: Int) -> Int {
        let u = nextUInt64()
        return Int(u % UInt64(max(1, upperBoundExclusive)))
    }
}

// MARK: - Helpers

@inline(__always) private func clamp(_ x: Float, _ a: Float, _ b: Float) -> Float { min(max(x, a), b) }

@inline(__always) private func smoothBiasToOne(_ x: Float, bias: Float) -> Float {
    // x in [0,1]. bias=0 => identity.
    // bias>0 => pushes toward 0.5; used to keep scaling near 1.0 after remap around 0.5.
    if bias <= 0 { return x }
    let k = max(0.0001, 1.0 + bias * 6.0)
    // symmetric "S" curve around 0.5
    let t = x - 0.5
    let y = 0.5 + t / (abs(t) * (k - 1.0) + 1.0)
    return clamp(y, 0, 1)
}

private func sampleAxisScale(
    rng: inout SplitMix64,
    style: CubeLetterStyle,
    sizeFactor01: Float
) -> SIMD3<Float> {
    // Base samples 0..1, then biased toward 0.5 (=> near 1.0 after remap)
    func sampleOne() -> Float {
        var u = rng.nextFloat01()
        u = smoothBiasToOne(u, bias: style.prismCubeBias)
        return u
    }

    // Optionally correlate elongation with cube size (bigger => more extreme)
    let corr = clamp(style.prismSizeCorrelation, 0, 1)
    let amp = mix(0.6, 1.0, mix(1.0 - corr, 1.0, sizeFactor01)) // mild effect

    func remap(_ u: Float, _ minV: Float, _ maxV: Float) -> Float {
        // map u in [0,1] to [min,max], with u=0.5 near mid; amp scales distance from 0.5
        let centered = (u - 0.5) * amp + 0.5
        return mix(minV, maxV, clamp(centered, 0, 1))
    }

    let ux = sampleOne()
    let uy = sampleOne()
    let uz = sampleOne()

    let s = SIMD3<Float>(
        remap(ux, style.prismScaleMin.x, style.prismScaleMax.x),
        remap(uy, style.prismScaleMin.y, style.prismScaleMax.y),
        remap(uz, style.prismScaleMin.z, style.prismScaleMax.z)
    )

    // Avoid degenerate near-zero dimensions.
    return SIMD3<Float>(max(0.05, s.x), max(0.05, s.y), max(0.05, s.z))
}

@inline(__always) private func hashScalar(_ scalar: UnicodeScalar) -> UInt64 {
    var x = UInt64(scalar.value)
    x ^= x >> 33
    x &*= 0xff51afd7ed558ccd
    x ^= x >> 33
    x &*= 0xc4ceb9fe1a85ec53
    x ^= x >> 33
    return x
}

@inline(__always) private func localToWorld(base: SIMD3<Float>, local: SIMD3<Float>, style: CubeLetterStyle) -> SIMD3<Float> {
    base + local * style.worldScale
}

// MARK: - Core

private func getLetterStrokes(_ char: Character) -> [[SIMD2<Float>]]? {
    let l: Float = -0.5
    let r: Float = 0.5
    let t: Float = 0.5
    let b: Float = -0.5
    let c: Float = 0.0
    
    switch char {
    case "A":
        return [
            [SIMD2(l, b), SIMD2(c, t)],
            [SIMD2(c, t), SIMD2(r, b)],
            [SIMD2(l * 0.5, c), SIMD2(r * 0.5, c)]
        ]
    case "B":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r * 0.8, t), SIMD2(r, t * 0.5), SIMD2(r * 0.8, c), SIMD2(l, c)],
            [SIMD2(l, c), SIMD2(r * 0.8, c), SIMD2(r, b * 0.5), SIMD2(r * 0.8, b), SIMD2(l, b)]
        ]
    case "C":
        return [
            [SIMD2(r, t * 0.8), SIMD2(c, t), SIMD2(l, c), SIMD2(c, b), SIMD2(r, b * 0.8)]
        ]
    case "D":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r * 0.6, t), SIMD2(r, c), SIMD2(r * 0.6, b), SIMD2(l, b)]
        ]
    case "E":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, t)],
            [SIMD2(l, c), SIMD2(r * 0.8, c)],
            [SIMD2(l, b), SIMD2(r, b)]
        ]
    case "F":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, t)],
            [SIMD2(l, c), SIMD2(r * 0.8, c)]
        ]
    case "G":
        return [
            [SIMD2(r, t * 0.8), SIMD2(c, t), SIMD2(l, c), SIMD2(c, b), SIMD2(r, b * 0.8), SIMD2(r, c * 0.8), SIMD2(c, c * 0.8)]
        ]
    case "H":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(r, b), SIMD2(r, t)],
            [SIMD2(l, c), SIMD2(r, c)]
        ]
    case "I":
        return [
            [SIMD2(c, b), SIMD2(c, t)],
            [SIMD2(l * 0.5, t), SIMD2(r * 0.5, t)],
            [SIMD2(l * 0.5, b), SIMD2(r * 0.5, b)]
        ]
    case "J":
        return [
            [SIMD2(r * 0.5, t), SIMD2(r * 0.5, b), SIMD2(c, b), SIMD2(l * 0.5, b * 0.5)]
        ]
    case "K":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, c), SIMD2(r, t)],
            [SIMD2(l, c), SIMD2(r, b)]
        ]
    case "L":
        return [
            [SIMD2(l, t), SIMD2(l, b)],
            [SIMD2(l, b), SIMD2(r, b)]
        ]
    case "M":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(c, c)],
            [SIMD2(c, c), SIMD2(r, t)],
            [SIMD2(r, t), SIMD2(r, b)]
        ]
    case "N":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, b)],
            [SIMD2(r, b), SIMD2(r, t)]
        ]
    case "O":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, t)],
            [SIMD2(r, t), SIMD2(r, b)],
            [SIMD2(r, b), SIMD2(l, b)]
        ]
    case "P":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, t), SIMD2(r, c), SIMD2(l, c)]
        ]
    case "Q":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, t)],
            [SIMD2(r, t), SIMD2(r, b)],
            [SIMD2(r, b), SIMD2(l, b)],
            [SIMD2(c, c), SIMD2(r, b)]
        ]
    case "R":
        return [
            [SIMD2(l, b), SIMD2(l, t)],
            [SIMD2(l, t), SIMD2(r, t), SIMD2(r, c), SIMD2(l, c)],
            [SIMD2(l, c), SIMD2(r, b)]
        ]
    case "S":
        return [
            [SIMD2(r, t), SIMD2(l, t), SIMD2(l, c), SIMD2(r, c), SIMD2(r, b), SIMD2(l, b)]
        ]
    case "T":
        return [
            [SIMD2(c, b), SIMD2(c, t)],
            [SIMD2(l, t), SIMD2(r, t)]
        ]
    case "U":
        return [
            [SIMD2(l, t), SIMD2(l, b), SIMD2(r, b), SIMD2(r, t)]
        ]
    case "V":
        return [
            [SIMD2(l, t), SIMD2(c, b)],
            [SIMD2(c, b), SIMD2(r, t)]
        ]
    case "W":
        return [
            [SIMD2(l, t), SIMD2(l * 0.5, b)],
            [SIMD2(l * 0.5, b), SIMD2(c, c)],
            [SIMD2(c, c), SIMD2(r * 0.5, b)],
            [SIMD2(r * 0.5, b), SIMD2(r, t)]
        ]
    case "X":
        return [
            [SIMD2(l, b), SIMD2(r, t)],
            [SIMD2(l, t), SIMD2(r, b)]
        ]
    case "Y":
        return [
            [SIMD2(l, t), SIMD2(c, c)],
            [SIMD2(r, t), SIMD2(c, c)],
            [SIMD2(c, c), SIMD2(c, b)]
        ]
    case "Z":
        return [
            [SIMD2(l, t), SIMD2(r, t)],
            [SIMD2(r, t), SIMD2(l, b)],
            [SIMD2(l, b), SIMD2(r, b)]
        ]
    default:
        return nil
    }
}

func cubesForAbstractCubeText(
    _ text: String,
    origin: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
    style: CubeLetterStyle = CubeLetterStyle(),
    seed: UInt64 = 0
) -> [Cube] {
    var cubes: [Cube] = []
    cubes.reserveCapacity(max(1, text.count) * max(1, style.cubesPerLetter))

    let W = style.letterWidth
    let H = style.letterHeight
    let D = style.letterDepth

    let advance = W + style.kerning
    let spaceAdv = style.spaceAdvance

    var penX: Float = 0
    var penY: Float = 0
    var letterIndex = 0

    func wrapIfNeeded(nextAdvance: Float) {
        guard style.maxLineWidth > 0 else { return }
        if (penX + nextAdvance) > style.maxLineWidth {
            penX = 0
            penY -= (H + style.lineSpacing)
        }
    }

    for ch in text {
        if ch == "\n" {
            penX = 0
            penY -= (H + style.lineSpacing)
            continue
        }
        if ch == " " || ch == "\t" {
            wrapIfNeeded(nextAdvance: spaceAdv)
            penX += spaceAdv
            continue
        }

        let scalar = ch.unicodeScalars.first ?? UnicodeScalar(63)!
        let s = hashScalar(scalar)
        let letterSeed = seed ^ (s &* 0x9E3779B97F4A7C15) ^ UInt64(letterIndex &* 0x85EBCA6B)
        var rng = SplitMix64(seed: letterSeed)

        wrapIfNeeded(nextAdvance: advance)

        let letterBase = origin + SIMD3<Float>(penX, penY, 0) * style.worldScale

        let halfW = W * 0.5
        let halfH = H * 0.5
        
        var localPoints: [SIMD3<Float>] = []
        localPoints.reserveCapacity(style.cubesPerLetter)
        
        if let strokes = getLetterStrokes(ch) {
            for stroke in strokes {
                for i in 0..<(stroke.count - 1) {
                    let p1 = stroke[i] * SIMD2(W, H)
                    let p2 = stroke[i+1] * SIMD2(W, H)
                    let delta = p2 - p1
                    let segLen = simd_length(delta)
                    
                    if segLen < 0.001 { continue }
                    
                    let dir = delta / segLen
                    let angle = atan2(dir.y, dir.x)
                    
                    var covered: Float = 0
                    
                    while covered < segLen {
                        // Determine thickness (Y/Z size) of next prism
                        let r = rng.nextFloat01()
                        let sizeFactor = 1.0 + style.sizeJitter * (pow(r, 0.35) - 0.5) * 2.0
                        let thickness = max(style.baseCubeSize * 0.15, style.baseCubeSize * sizeFactor)
                        
                        // Determine length of this prism
                        let remaining = segLen - covered
                        
                        // We want to favor long pieces to represent straight lines.
                        // Try to cover a significant portion of the remaining segment.
                        // Base target is the full remaining length.
                        var targetLen = remaining
                        
                        // Occasionally split long segments for style, but prefer keeping them intact or large chunks.
                        // Only split if the remaining part is significantly larger than the thickness.
                        if remaining > thickness * 10.0 {
                            // 30% chance to split
                            if rng.nextFloat01() < 0.3 {
                                // Split somewhere between 50% and 90% of the remaining length
                                targetLen = remaining * (0.5 + 0.4 * rng.nextFloat01())
                            }
                        }
                        
                        // Ensure we don't create tiny slivers at the end
                        if (remaining - targetLen) < thickness {
                            targetLen = remaining
                        }
                        
                        let actualLen = targetLen
                        
                        let midT = covered + actualLen * 0.5
                        let p = p1 + dir * midT
                        
                        // Jitter
                        // Reduce jitter for structural strokes to keep them readable
                        let jitterScale: Float = 0.1
                        let jx = rng.nextSigned() * style.jitterXY * jitterScale
                        let jy = rng.nextSigned() * style.jitterXY * jitterScale
                        let jz = rng.nextSigned() * D * 0.5 * style.jitterZ
                        
                        // Orientation
                        // Align X with direction (angle)
                        // We ignore baseTilt for Z because it breaks the alignment with the stroke.
                        let ox = rng.nextSigned() * style.rotationJitter * 0.3
                        let oy = rng.nextSigned() * style.rotationJitter * 0.3
                        let oz = angle + rng.nextSigned() * style.rotationJitter * 0.2
                        
                        // Scale
                        let scaleX = actualLen / thickness
                        
                        let sizeFactor01 = clamp((sizeFactor - (1.0 - style.sizeJitter)) / max(0.0001, (2.0 * style.sizeJitter)), 0, 1)
                        var axisScale = sampleAxisScale(rng: &rng, style: style, sizeFactor01: sizeFactor01)
                        
                        // Overwrite X scale to match length
                        axisScale.x = scaleX
                        
                        let worldCenter = localToWorld(base: letterBase, local: SIMD3(p.x + jx, p.y + jy, jz), style: style)
                        
                        cubes.append(Cube(
                            center: worldCenter,
                            size: thickness * style.worldScale,
                            orientation: SIMD3(ox, oy, oz),
                            axisScale: axisScale
                        ))
                        
                        covered += actualLen
                    }
                }
            }
            
        } else {
            // Fallback to original random walk logic
            let anchorCount = 5 + rng.nextInt(4)
            var anchors: [SIMD2<Float>] = []
            anchors.reserveCapacity(anchorCount)
            for _ in 0..<anchorCount {
                anchors.append(SIMD2<Float>(rng.nextSigned() * halfW, rng.nextSigned() * halfH))
            }

            let coherence = clamp(style.coherence, 0, 1)
            let strokeBudget = Int(Float(style.cubesPerLetter) * coherence)
            let scatterBudget = max(0, style.cubesPerLetter - strokeBudget)

            let sc = max(1, style.strokeCount)
            let steps = max(1, style.strokeSteps)
            let stepLen = max(0.0001, style.strokeStep)

            var produced = 0
            for _ in 0..<sc {
                if produced >= strokeBudget { break }

                var p2 = anchors[rng.nextInt(anchors.count)]
                p2.x += rng.nextSigned() * halfW * 0.15
                p2.y += rng.nextSigned() * halfH * 0.15

                var target = anchors[rng.nextInt(anchors.count)]

                for i in 0..<steps {
                    if produced >= strokeBudget { break }

                    if i % (6 + rng.nextInt(5)) == 0 {
                        target = anchors[rng.nextInt(anchors.count)]
                    }

                    let dirRand = SIMD2<Float>(rng.nextSigned(), rng.nextSigned())
                    let toTarget = target - p2
                    let drift = toTarget * style.driftToAnchors
                    var dir = dirRand + drift
                    let len = max(0.0001, simd_length(dir))
                    dir /= len

                    p2 += dir * stepLen
                    p2.x = clamp(p2.x, -halfW, halfW)
                    p2.y = clamp(p2.y, -halfH, halfH)

                    let z = rng.nextSigned() * D * 0.5 * style.jitterZ
                    let jx = rng.nextSigned() * style.jitterXY
                    let jy = rng.nextSigned() * style.jitterXY

                    localPoints.append(SIMD3<Float>(p2.x + jx, p2.y + jy, z))
                    produced += 1

                    if produced < strokeBudget && rng.nextFloat01() < 0.18 {
                        let ez = z + rng.nextSigned() * D * 0.15
                        localPoints.append(SIMD3<Float>(p2.x + jx * 1.6, p2.y + jy * 1.6, ez))
                        produced += 1
                    }
                }
            }

            if scatterBudget > 0 {
                for _ in 0..<scatterBudget {
                    let a = anchors[rng.nextInt(anchors.count)]
                    let t = pow(rng.nextFloat01(), 0.55)
                    let px = mix(a.x, rng.nextSigned() * halfW, t)
                    let py = mix(a.y, rng.nextSigned() * halfH, t)
                    let pz = rng.nextSigned() * D * 0.5 * style.jitterZ
                    localPoints.append(SIMD3<Float>(px, py, pz))
                }
            }
        }

        let baseTilt = style.tiltPerLetter * Float(letterIndex)

        // Points -> prisms
        for lp in localPoints {
            let r = rng.nextFloat01()
            let sizeFactor = 1.0 + style.sizeJitter * (pow(r, 0.35) - 0.5) * 2.0
            let cubeSize = max(style.baseCubeSize * 0.15, style.baseCubeSize * sizeFactor)

            // 0..1 size factor for correlation usage
            let sizeFactor01 = clamp((sizeFactor - (1.0 - style.sizeJitter)) / max(0.0001, (2.0 * style.sizeJitter)), 0, 1)

            let axisScale = sampleAxisScale(rng: &rng, style: style, sizeFactor01: sizeFactor01)

            let ox = rng.nextSigned() * style.rotationJitter + baseTilt.x
            let oy = rng.nextSigned() * style.rotationJitter + baseTilt.y
            let oz = rng.nextSigned() * style.rotationJitter + baseTilt.z

            let worldCenter = localToWorld(base: letterBase, local: lp, style: style)

            cubes.append(
                Cube(
                    center: worldCenter,
                    size: cubeSize,
                    orientation: SIMD3<Float>(ox, oy, oz),
                    axisScale: axisScale
                )
            )
        }

        penX += advance
        letterIndex += 1
    }

    return cubes
}
