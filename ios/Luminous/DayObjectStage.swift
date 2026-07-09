//
//  DayObjectStage.swift
//  Luminous — 今天的小机器: the SceneKit stage the day-object lives on.
//
//  CP-B: just the EMPTY stage — a soft pedestal under warm light, slowly
//  turning, with a faint glass seed hovering to say "something will grow here."
//  Parts attach in CP-C. Skin-aware: every color comes from the theme tokens,
//  so the stage re-skins with the app. Materials stay the app's vocabulary
//  (wood / paper / glass / brass / cloth / light) — never chrome, never plastic.
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
    var reduceMotion: Bool = false

    var body: some View {
        SceneView(
            scene: makeScene(),
            options: reduceMotion ? [] : [.rendersContinuously]
        )
        .accessibilityLabel("今天的小机器，一个还空着的台子")
    }

    private func c(_ color: Color) -> StageColor { StageColor(color) }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = c(tokens.background)

        // Camera — a gentle three-quarter look down onto the stage.
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.fieldOfView = 42
        cam.camera?.wantsHDR = false
        cam.position = SCNVector3(0, 1.6, 6.2)
        cam.eulerAngles = SCNVector3(-0.22, 0, 0)
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
        key.position = SCNVector3(-3, 4.5, 4)
        scene.rootNode.addChildNode(key)

        // The turning group: pedestal + a faint seed above it.
        let group = SCNNode()

        let base = SCNNode(geometry: SCNCylinder(radius: 1.15, height: 0.26))
        if let m = base.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.surface)
            m.roughness.contents = StageColor.gray
            m.lightingModel = .physicallyBased
        }
        base.position = SCNVector3(0, 0, 0)
        group.addChildNode(base)

        // A thin brass rim, catching the key light — a little craft, not a plinth.
        let rim = SCNNode(geometry: SCNTorus(ringRadius: 1.15, pipeRadius: 0.04))
        if let m = rim.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.accentText)
            m.metalness.contents = 0.6
            m.lightingModel = .physicallyBased
        }
        rim.position = SCNVector3(0, 0.13, 0)
        group.addChildNode(rim)

        // The empty seed — a soft glass sphere hovering, gently lit from within.
        let seed = SCNNode(geometry: SCNSphere(radius: 0.32))
        if let m = seed.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.accent)
            m.transparency = 0.42
            m.emission.contents = c(tokens.accentSoft)
            m.lightingModel = .physicallyBased
        }
        seed.position = SCNVector3(0, 0.95, 0)
        group.addChildNode(seed)

        scene.rootNode.addChildNode(group)

        if !reduceMotion {
            let spin = SCNAction.repeatForever(
                .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 26))
            group.runAction(spin)
            // The seed breathes a little, up and down.
            let up = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.2)
            up.timingMode = .easeInEaseOut
            let down = up.reversed()
            seed.runAction(.repeatForever(.sequence([up, down])))
        }

        return scene
    }
}
