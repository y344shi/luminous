//
//  DayObjectStage.swift
//  Luminous — 今天的小机器: the SceneKit stage the day-object lives on.
//
//  CP-B: the empty stage. CP-C: today's parts attach — one node per DayPart,
//  geometry by material, size/glow/motor from how the wish felt. CP-D: "Play
//  today" — a gentle ~10s scene chosen by time-of-day + weather: the sky tints
//  to the hour, the camera drifts, the little machine rises and arcs, then it
//  all settles. Never a race. Reduce Motion → a still hero pose, no play.
//
//  Skin-aware: every color comes from the theme tokens (the sky from DayGrade).
//  Materials stay the app's vocabulary (wood / paper / glass / brass / cloth /
//  light) — never chrome, never plastic. Count-free by design.
//

import SwiftUI
import SceneKit

#if canImport(UIKit)
import UIKit
typealias StageColor = UIColor
#else
import AppKit
typealias StageColor = NSColor
#endif

struct DayObjectStage: View {
    let tokens: ThemeTokens
    var parts: [DayPart] = []
    var reduceMotion: Bool = false
    /// Bump to play the ~10s scene once.
    var playSignal: Int = 0
    /// The hour's sky [top, horizon, ground] (DayGrade.colors) for the scene.
    var skyColors: [Color] = []
    /// Rain / snow / fog → a softer, gentler sky.
    var soften: Bool = false

    @State private var scene = SCNScene()
    @State private var camera = SCNNode()
    @State private var craft = SCNNode()
    @State private var built = false

    var body: some View {
        SceneView(
            scene: scene,
            pointOfView: camera,
            options: reduceMotion ? [] : [.rendersContinuously]
        )
        .accessibilityLabel(parts.isEmpty
            ? "今天的小机器，一个还空着的台子"
            : "今天的小机器，上面已经长出了零件")
        .onAppear { if !built { build(); built = true } }
        .onChange(of: parts.count) { _, _ in build() }
        .onChange(of: reduceMotion) { _, _ in build() }
        .onChange(of: playSignal) { _, _ in runPlay() }
    }

    private func c(_ color: Color) -> StageColor { StageColor(color) }

    /// Cross-platform SCNVector3 from Doubles (components are Float on iOS,
    /// CGFloat on macOS — computed values need the explicit conversion).
    private func v(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
        #if canImport(UIKit)
        return SCNVector3(Float(x), Float(y), Float(z))
        #else
        return SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #endif
    }

    // MARK: build the (persistent) scene graph

    private func build() {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        scene.background.contents = c(tokens.background)

        // Camera — a gentle three-quarter look down onto the stage.
        camera.camera = camera.camera ?? SCNCamera()
        camera.camera?.fieldOfView = 42
        camera.camera?.wantsHDR = false
        camera.removeAllActions()
        camera.position = v(0, 1.6, 6.2)
        camera.eulerAngles = v(-0.22, 0, 0)
        scene.rootNode.addChildNode(camera)

        // Soft ambient fill from the surface color, plus one warm key light.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = c(tokens.surfaceSoft)
        ambient.light!.intensity = 480
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light!.type = .omni
        key.light!.color = c(tokens.accentSoft)
        key.light!.intensity = 850
        key.position = v(-3, 4.5, 4)
        scene.rootNode.addChildNode(key)

        // The turning craft: pedestal + parts (or a seed when empty).
        craft.childNodes.forEach { $0.removeFromParentNode() }
        craft.removeAllActions()
        craft.position = v(0, 0, 0)
        craft.eulerAngles = v(0, 0, 0)

        let base = SCNNode(geometry: SCNCylinder(radius: 1.15, height: 0.26))
        if let m = base.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.surface)
            m.roughness.contents = StageColor.gray
            m.lightingModel = .physicallyBased
        }
        base.position = v(0, 0, 0)
        craft.addChildNode(base)

        let rim = SCNNode(geometry: SCNTorus(ringRadius: 1.15, pipeRadius: 0.04))
        if let m = rim.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.accentText)
            m.metalness.contents = 0.6
            m.lightingModel = .physicallyBased
        }
        rim.position = v(0, 0.13, 0)
        craft.addChildNode(rim)

        if parts.isEmpty {
            let seed = SCNNode(geometry: SCNSphere(radius: 0.32))
            if let m = seed.geometry?.firstMaterial {
                m.diffuse.contents = c(tokens.accent)
                m.transparency = 0.42
                m.emission.contents = c(tokens.accentSoft)
                m.lightingModel = .physicallyBased
            }
            seed.position = v(0, 0.95, 0)
            craft.addChildNode(seed)
            if !reduceMotion {
                let up = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.2)
                up.timingMode = .easeInEaseOut
                seed.runAction(.repeatForever(.sequence([up, up.reversed()])))
            }
        } else {
            for (i, part) in parts.enumerated() {
                craft.addChildNode(partNode(part, index: i, count: parts.count))
            }
        }

        scene.rootNode.addChildNode(craft)

        if !reduceMotion {
            craft.runAction(.repeatForever(
                .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 26)), forKey: "spin")
        }
    }

    // MARK: Play today — a gentle ~10s scene

    private func runPlay() {
        guard !reduceMotion, !parts.isEmpty else { return }

        // The sky tints to the hour (softened in rain/snow/fog), then settles.
        let horizon: Color = {
            if soften { return skyColors.first ?? tokens.surfaceSoft }
            return skyColors.count > 1 ? skyColors[1] : tokens.accentSoft
        }()
        let sky = c(horizon)
        let home = c(tokens.background)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.2
        scene.background.contents = sky
        SCNTransaction.commit()

        // Camera drifts out and back — a slow look-around, never a swoop.
        camera.removeAction(forKey: "play")
        let camOut = SCNAction.moveBy(x: 1.1, y: 0.35, z: -0.5, duration: 5)
        camOut.timingMode = .easeInEaseOut
        camera.runAction(.sequence([camOut, camOut.reversed()]), forKey: "play")

        // The little machine rises and arcs, then comes home.
        craft.removeAction(forKey: "drift")
        let rise = SCNAction.moveBy(x: -0.45, y: 0.28, z: 0, duration: 5)
        rise.timingMode = .easeInEaseOut
        craft.runAction(.sequence([rise, rise.reversed()]), forKey: "drift")

        // After the scene, let the sky settle back.
        scene.rootNode.removeAction(forKey: "settle")
        let restore = SCNAction.run { _ in
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 2.2
            scene.background.contents = home
            SCNTransaction.commit()
        }
        scene.rootNode.runAction(.sequence([.wait(duration: 9.5), restore]), forKey: "settle")
    }

    // MARK: one part → one node

    private func partNode(_ part: DayPart, index: Int, count: Int) -> SCNNode {
        let node = SCNNode(geometry: geometry(for: part.kind.material))
        if let m = node.geometry?.firstMaterial {
            m.diffuse.contents = c(materialColor(part.kind.material))
            m.lightingModel = .physicallyBased
            switch part.kind.material {
            case .glass:
                m.transparency = 0.5
            case .brass:
                m.metalness.contents = 0.7
                m.roughness.contents = 0.3
            case .light:
                m.metalness.contents = 0.0
            case .cloth, .wood, .paper:
                m.roughness.contents = 0.9
            }
            if part.glow > 0 {
                m.emission.contents = c(tokens.accentSoft)
                m.emission.intensity = CGFloat(part.glow)
            }
        }

        let s = part.scale                                    // 0.6 … 1.3
        node.scale = v(s, s, s)

        let ang = 2 * Double.pi * Double(index) / Double(max(count, 1)) - Double.pi / 2
        let r = 0.66
        node.position = v(cos(ang) * r, 0.5 + s * 0.08, sin(ang) * r)

        if reduceMotion { return node }
        if part.motor > 0 {
            let dur = 6.0 - 3.2 * part.motor
            node.runAction(.repeatForever(
                .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: dur)))
        } else {
            let up = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 2.6)
            up.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([up, up.reversed()])))
        }
        return node
    }

    private func geometry(for mat: PartMaterial) -> SCNGeometry {
        let d: CGFloat = 0.30
        switch mat {
        case .glass, .light:
            return SCNSphere(radius: d * 0.6)
        case .brass:
            return SCNTorus(ringRadius: d * 0.5, pipeRadius: d * 0.16)
        case .cloth:
            return SCNBox(width: d, height: d * 0.7, length: d, chamferRadius: d * 0.3)
        case .wood, .paper:
            return SCNBox(width: d, height: d * 0.5, length: d, chamferRadius: d * 0.06)
        }
    }

    private func materialColor(_ mat: PartMaterial) -> Color {
        switch mat {
        case .glass:  return tokens.accent
        case .brass:  return tokens.accentText
        case .light:  return tokens.accentSoft
        case .cloth:  return tokens.surfaceSoft
        case .wood:   return tokens.textMuted
        case .paper:  return tokens.surface
        }
    }
}
