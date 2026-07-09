//
//  DayObjectSnapshot.swift
//  Luminous — a still render of today's machine, for the keepsake (CP-E).
//
//  Builds a quiet, animation-free copy of the day-object scene and renders it
//  offscreen with SCNRenderer to a PNG, so 收进今天的痕迹 can keep an image of
//  how the machine looked. Deliberately duplicates the (small) node mapping
//  rather than coupling to the live DayObjectStage — the keepsake render is a
//  still, and staying decoupled keeps the animated stage safe. If Metal isn't
//  available the keepsake still works (nil image → the kept-marker + trace line).
//

import SwiftUI
import SceneKit
import Metal

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum DayObjectSnapshot {

    static func png(tokens: ThemeTokens, parts: [DayPart],
                    size: CGSize = CGSize(width: 640, height: 640)) -> Data? {
        guard !parts.isEmpty, let device = MTLCreateSystemDefaultDevice() else { return nil }
        let (scene, camera) = buildStill(tokens: tokens, parts: parts)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        #if canImport(UIKit)
        return image.pngData()
        #else
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #endif
    }

    // MARK: helpers (a still mirror of DayObjectStage's builder)

    private static func c(_ color: Color) -> StageColor { StageColor(color) }

    private static func v(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
        #if canImport(UIKit)
        return SCNVector3(Float(x), Float(y), Float(z))
        #else
        return SCNVector3(CGFloat(x), CGFloat(y), CGFloat(z))
        #endif
    }

    private static func buildStill(tokens: ThemeTokens, parts: [DayPart])
        -> (SCNScene, SCNNode) {
        let scene = SCNScene()
        scene.background.contents = c(tokens.background)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 42
        camera.position = v(0, 1.6, 6.2)
        camera.eulerAngles = v(-0.22, 0, 0)
        scene.rootNode.addChildNode(camera)

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

        let base = SCNNode(geometry: SCNCylinder(radius: 1.15, height: 0.26))
        if let m = base.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.surface)
            m.roughness.contents = StageColor.gray
            m.lightingModel = .physicallyBased
        }
        scene.rootNode.addChildNode(base)

        let rim = SCNNode(geometry: SCNTorus(ringRadius: 1.15, pipeRadius: 0.04))
        if let m = rim.geometry?.firstMaterial {
            m.diffuse.contents = c(tokens.accentText)
            m.metalness.contents = 0.6
            m.lightingModel = .physicallyBased
        }
        rim.position = v(0, 0.13, 0)
        scene.rootNode.addChildNode(rim)

        for (i, part) in parts.enumerated() {
            scene.rootNode.addChildNode(partNode(part, index: i, count: parts.count, tokens: tokens))
        }
        return (scene, camera)
    }

    private static func partNode(_ part: DayPart, index: Int, count: Int,
                                 tokens: ThemeTokens) -> SCNNode {
        let node = SCNNode(geometry: DayCraftArt.geometry(for: part.kind))
        if let m = node.geometry?.firstMaterial {
            DayCraftArt.apply(m, kind: part.kind, glow: part.glow, tokens: tokens)
        }
        let s = part.scale
        node.scale = v(s, s, s)
        let ang = 2 * Double.pi * Double(index) / Double(max(count, 1)) - Double.pi / 2
        let r = 0.66
        node.position = v(cos(ang) * r, 0.5 + s * 0.08, sin(ang) * r)
        return node
    }
}
