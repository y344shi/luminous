//
//  DayObjectStage.swift
//  Luminous — 今天的小机器: the SceneKit stage the day-object lives on.
//
//  CP-C: today's parts attach onto the stage. Each completed wish's DayPart
//  becomes a small node — geometry by its material, size/glow/motor from how the
//  wish felt — arranged evenly around the slowly turning pedestal. An empty
//  stage still shows one faint glass seed ("something will grow here").
//  Skin-aware: every color comes from the theme tokens, so the stage re-skins
//  with the app. Materials stay the app's vocabulary (wood / paper / glass /
//  brass / cloth / light) — never chrome, never plastic. Count-free by design.
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

    var body: some View {
        SceneView(
            scene: makeScene(),
            options: reduceMotion ? [] : [.rendersContinuously]
        )
        .accessibilityLabel(parts.isEmpty
            ? "今天的小机器，一个还空着的台子"
            : "今天的小机器，上面已经长出了零件")
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

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = c(tokens.background)

        // Camera — a gentle three-quarter look down onto the stage.
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 42
        cam.camera?.wantsHDR = false
        cam.position = v(0, 1.6, 6.2)
        cam.eulerAngles = v(-0.22, 0, 0)
        scene.rootNode.addChildNode(cam)

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

        // The turning group: pedestal + the parts (or a seed when empty).
        let group = SCNNode()

        let base = SCNNode(geometry: SCNCylinder(radius: 1.15, height: 0.26))
        if let m = base.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.surface)
            m.roughness.contents = StageColor.gray
            m.lightingModel = .physicallyBased
        }
        base.position = v(0, 0, 0)
        group.addChildNode(base)

        // A thin brass rim, catching the key light — a little craft, not a plinth.
        let rim = SCNNode(geometry: SCNTorus(ringRadius: 1.15, pipeRadius: 0.04))
        if let m = rim.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.accentText)
            m.metalness.contents = 0.6
            m.lightingModel = .physicallyBased
        }
        rim.position = v(0, 0.13, 0)
        group.addChildNode(rim)

        if parts.isEmpty {
            // The empty seed — a soft glass sphere hovering, lit from within.
            let seed = SCNNode(geometry: SCNSphere(radius: 0.32))
            if let m = seed.geometry?.firstMaterial {
                m.diffuse.contents = c(tokens.accent)
                m.transparency = 0.42
                m.emission.contents = c(tokens.accentSoft)
                m.lightingModel = .physicallyBased
            }
            seed.position = v(0, 0.95, 0)
            group.addChildNode(seed)
            if !reduceMotion {
                let up = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.2)
                up.timingMode = .easeInEaseOut
                seed.runAction(.repeatForever(.sequence([up, up.reversed()])))
            }
        } else {
            // Today's parts, arranged evenly around the pedestal.
            for (i, part) in parts.enumerated() {
                group.addChildNode(partNode(part, index: i, count: parts.count))
            }
        }

        scene.rootNode.addChildNode(group)

        if !reduceMotion {
            // The whole little machine turns slowly.
            group.runAction(.repeatForever(
                .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 26)))
        }

        return scene
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

        // Evenly around a ring on top of the pedestal, front-first.
        let ang = 2 * Double.pi * Double(index) / Double(max(count, 1)) - Double.pi / 2
        let r = 0.66
        node.position = v(cos(ang) * r, 0.5 + s * 0.08, sin(ang) * r)

        if reduceMotion {
            return node
        }
        if part.motor > 0 {
            // A working part turns — stronger feeling, livelier motor.
            let dur = 6.0 - 3.2 * part.motor
            node.runAction(.repeatForever(
                .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: dur)))
        } else {
            // A quiet part (tinyButReal) doesn't spin — it just breathes.
            let up = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 2.6)
            up.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([up, up.reversed()])))
        }
        return node
    }

    /// Geometry per material — the app's own vocabulary, never chrome/plastic.
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
