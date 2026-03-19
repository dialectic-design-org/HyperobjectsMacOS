//
//  RencerConfigurationsView.swift
//  HyperobjectsMacOS
//
//  Created by Erwin Hoogerwoord on 28/10/2024.
//

import SwiftUI

struct RenderConfigurationsView: View {
    @EnvironmentObject var sceneManager: SceneManager
    @EnvironmentObject var renderConfigurations: RenderConfigurations
    @EnvironmentObject var videoStreamManager: VideoStreamManager
    
    @State private var camDistance: Float = 5.0
    
    @State private var binDepth: Float = 16
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                Toggle(
                    "Render Points",
                    isOn: $renderConfigurations.renderPoints
                )
                
                Toggle(
                    "Render SDF Lines",
                    isOn: $renderConfigurations.renderSDFLines
                )
                
                Toggle(
                    "Render Lines Overlay",
                    isOn: $renderConfigurations.renderLinesOverlay
                )
                
                Toggle(
                    "Show overlay",
                    isOn: $renderConfigurations.showOverlay
                )

                Toggle(
                    "Show square bounds",
                    isOn: $renderConfigurations.showSquareBounds
                )
                
                Toggle(
                    "Run script on timer",
                    isOn: $renderConfigurations.runScriptOnFrameChange
                )
                
                Toggle(
                    "Show audio controls",
                    isOn: $renderConfigurations.showAudioControls
                )
                
                Text("Projection mix")
                Slider(value: $renderConfigurations.projectionMix, in: 0...1.0)
                
                Text("Camera Distance: \(String(format: "%.1f", renderConfigurations.cameraDistance))")
                Slider(value: $renderConfigurations.cameraDistance, in: 0...50.0)
                
                Text("Orthographic projection height: \(String(format: "%.1f", renderConfigurations.orthographicProjectionHeight))")
                Slider(value: $renderConfigurations.orthographicProjectionHeight, in: 0...10.0)
                
                Text("FOV Division: \(String(format: "%.1f", renderConfigurations.FOVDivision))")
                Slider(value: $renderConfigurations.FOVDivision, in: 0...10.0)
                
                Text("Previous color visibility: \(String(format: "%.2f", renderConfigurations.previousColorVisibility))")
                Slider(value: $renderConfigurations.previousColorVisibility, in: 0...1.0)
                
                
                Text("Bin visibility")
                Slider(value: $renderConfigurations.binVisibility, in: 0...10.0)
                
                Text("Bin grid visibility")
                Slider(value: $renderConfigurations.binGridVisibility, in: 0...1.0)
                
                Text("Bounding box visibility")
                Slider(value: $renderConfigurations.boundingBoxVisibility, in: 0...1.0)
                
                Text("Line color strength")
                Slider(value: $renderConfigurations.lineColorStrength, in: 0...1.0)
                
                Text("Line debug gradient strength")
                Slider(value: $renderConfigurations.lineTimeDebugGradientStrength, in: 0...1.0)
                
                Text("Line Time Debug Gradient Color Start")
                ColorPickerControlView(colorInput: renderConfigurations.lineTimeDebugStartGradientColor)
                
                Text("Line Time Debug Gradient Color End")
                ColorPickerControlView(colorInput: renderConfigurations.lineTimeDebugEndGradientColor)
                
                Text("Blend radius")
                Slider(value: $renderConfigurations.blendRadius, in: 0...1.0)
                
                Text("Blend intensity")
                Slider(value: $renderConfigurations.blendIntensity, in: 0...1.0)
                
                Text("Bin depth rendering")
                Slider(value: $binDepth,
                       in: 1.0...32.0,
                       step: 1
                ).onChange(of: binDepth) { oldValue, newValue in
                    renderConfigurations.binDepth = Int(newValue)
                }
                
                Text("Background color")
                ColorPickerControlView(colorInput: renderConfigurations.backgroundColor)

                Divider().padding(.vertical, 8)

                // Chromatic Aberration Controls
                Text("Chromatic Aberration").font(.headline)

                Toggle(
                    "Enable Chromatic Aberration",
                    isOn: $renderConfigurations.chromaticAberrationEnabled
                )

                Text("Intensity: \(String(format: "%.2f", renderConfigurations.chromaticAberrationIntensity))")
                Slider(value: $renderConfigurations.chromaticAberrationIntensity, in: 0...1.0)

                Toggle(
                    "Spectral Mode (Physically Accurate)",
                    isOn: $renderConfigurations.chromaticAberrationUseSpectralMode
                )

                if renderConfigurations.chromaticAberrationUseSpectralMode {
                    // Spectral mode controls
                    Text("Dispersion Strength: \(String(format: "%.1f", renderConfigurations.chromaticAberrationDispersionStrength)) px")
                    Slider(value: $renderConfigurations.chromaticAberrationDispersionStrength, in: 0...30)

                    Text("Reference λ: \(String(format: "%.0f", renderConfigurations.chromaticAberrationReferenceWavelength)) nm")
                    Slider(value: $renderConfigurations.chromaticAberrationReferenceWavelength, in: 450...650)
                    Text("(No shift at reference wavelength)").font(.caption).foregroundColor(.secondary)
                } else {
                    // RGB mode controls
                    Text("Red Offset: \(String(format: "%.1f", renderConfigurations.chromaticAberrationRedOffset)) px")
                    Slider(value: $renderConfigurations.chromaticAberrationRedOffset, in: -20...0)

                    Text("Green Offset: \(String(format: "%.1f", renderConfigurations.chromaticAberrationGreenOffset)) px")
                    Slider(value: $renderConfigurations.chromaticAberrationGreenOffset, in: -10...10)

                    Text("Blue Offset: \(String(format: "%.1f", renderConfigurations.chromaticAberrationBlueOffset)) px")
                    Slider(value: $renderConfigurations.chromaticAberrationBlueOffset, in: 0...20)
                }

                Text("Radial Power: \(String(format: "%.2f", renderConfigurations.chromaticAberrationRadialPower))")
                Slider(value: $renderConfigurations.chromaticAberrationRadialPower, in: 0.5...4.0)

                Toggle(
                    "Radial Mode",
                    isOn: $renderConfigurations.chromaticAberrationUseRadialMode
                )

                if !renderConfigurations.chromaticAberrationUseRadialMode {
                    Text("Direction Angle: \(String(format: "%.0f", renderConfigurations.chromaticAberrationAngle * 180 / .pi))°")
                    Slider(value: $renderConfigurations.chromaticAberrationAngle, in: 0...(2 * .pi))
                }

                Text("Presets").font(.subheadline).padding(.top, 4)

                if renderConfigurations.chromaticAberrationUseSpectralMode {
                    // Spectral presets
                    HStack {
                        Button("Subtle Lens") {
                            applySpectralPreset(intensity: 0.6, dispersion: 3.0, refWavelength: 550, power: 2.0)
                        }
                        Button("Vintage") {
                            applySpectralPreset(intensity: 0.8, dispersion: 8.0, refWavelength: 580, power: 1.5)
                        }
                    }
                    HStack {
                        Button("Strong Prism") {
                            applySpectralPreset(intensity: 1.0, dispersion: 15.0, refWavelength: 550, power: 1.0)
                        }
                        Button("Cheap Lens") {
                            applySpectralPreset(intensity: 0.7, dispersion: 6.0, refWavelength: 520, power: 2.5)
                        }
                    }
                } else {
                    // RGB presets
                    HStack {
                        Button("Subtle") {
                            applyRGBPreset(intensity: 0.5, red: -1.0, green: 0.0, blue: 1.0, power: 2.0, radial: true)
                        }
                        Button("Classic") {
                            applyRGBPreset(intensity: 0.7, red: -3.0, green: 0.0, blue: 3.0, power: 1.5, radial: true)
                        }
                        Button("VHS") {
                            applyRGBPreset(intensity: 1.0, red: -8.0, green: 2.0, blue: 8.0, power: 0.5, radial: true)
                        }
                    }
                    HStack {
                        Button("Prism") {
                            applyRGBPreset(intensity: 0.8, red: -5.0, green: 0.0, blue: 5.0, power: 1.0, radial: true)
                        }
                        Button("Drift") {
                            applyRGBPreset(intensity: 0.6, red: -4.0, green: 0.0, blue: 4.0, power: 1.0, radial: false)
                            renderConfigurations.chromaticAberrationAngle = 0.0
                        }
                    }
                }

                Divider().padding(.vertical, 8)

                // Video Output
                Text("Video Output").font(.headline)

                Toggle("Syphon Output", isOn: $videoStreamManager.syphonEnabled)
                    .onChange(of: videoStreamManager.syphonEnabled) { _, enabled in
                        if enabled {
                            videoStreamManager.startSyphon()
                        } else {
                            videoStreamManager.stopSyphon()
                        }
                    }

                Toggle("NDI Output", isOn: $videoStreamManager.ndiEnabled)
                    .disabled(true)
                    .help("NDI support coming soon")

            }
        }.padding()
    }

    private func applyRGBPreset(intensity: Float, red: Float, green: Float, blue: Float, power: Float, radial: Bool) {
        renderConfigurations.chromaticAberrationEnabled = true
        renderConfigurations.chromaticAberrationUseSpectralMode = false
        renderConfigurations.chromaticAberrationIntensity = intensity
        renderConfigurations.chromaticAberrationRedOffset = red
        renderConfigurations.chromaticAberrationGreenOffset = green
        renderConfigurations.chromaticAberrationBlueOffset = blue
        renderConfigurations.chromaticAberrationRadialPower = power
        renderConfigurations.chromaticAberrationUseRadialMode = radial
    }

    private func applySpectralPreset(intensity: Float, dispersion: Float, refWavelength: Float, power: Float) {
        renderConfigurations.chromaticAberrationEnabled = true
        renderConfigurations.chromaticAberrationUseSpectralMode = true
        renderConfigurations.chromaticAberrationIntensity = intensity
        renderConfigurations.chromaticAberrationDispersionStrength = dispersion
        renderConfigurations.chromaticAberrationReferenceWavelength = refWavelength
        renderConfigurations.chromaticAberrationRadialPower = power
        renderConfigurations.chromaticAberrationUseRadialMode = true
    }
}

