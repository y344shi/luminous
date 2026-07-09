//
//  DayCraftArt.swift
//  Luminous — 今天的小机器: the ONE source of truth for how a part looks.
//
//  CP-F: per-KIND shapes (a sail reads unlike a propeller unlike an engine),
//  in simple soft geometry, plus the material look (color / glass / brass /
//  light / cloth). Shared by the live DayObjectStage and the still
//  DayObjectSnapshot so the animated craft and its keepsake always match —
//  this also retires the CP-C/CP-E duplication (logged in D18). Materials stay
//  the app's vocabulary (wood / paper / glass / brass / cloth / light).
//

import SwiftUI
import SceneKit

enum DayCraftArt {

    /// Per-KIND geometry. Each part is a distinct little object, but always a
    /// soft, legible shape — never busy, never a game prop.
    static func geometry(for kind: PartKind) -> SCNGeometry {
        let d: CGFloat = 0.30
        switch kind {
        // recovery — soft, steadying
        case .cushionWheel:   return SCNTorus(ringRadius: d * 0.5, pipeRadius: d * 0.22)
        case .stabilizer:     return SCNCapsule(capRadius: d * 0.16, height: d * 1.1)
        // body / exploration — things that move you
        case .sail:           return SCNBox(width: d * 0.9, height: d * 1.1, length: d * 0.06, chamferRadius: d * 0.05)
        case .springLeg:      return SCNCapsule(capRadius: d * 0.12, height: d * 1.2)
        case .propeller:      return SCNBox(width: d * 1.4, height: d * 0.12, length: d * 0.22, chamferRadius: d * 0.05)
        // creation — light and power
        case .engine:         return SCNSphere(radius: d * 0.62)
        case .sparkCore:      return SCNPyramid(width: d * 0.7, height: d * 0.9, length: d * 0.7)
        // connection — small lights and signals
        case .passengerLight: return SCNSphere(radius: d * 0.5)
        case .lantern:        return SCNBox(width: d * 0.6, height: d * 0.82, length: d * 0.6, chamferRadius: d * 0.16)
        case .antenna:        return SCNCylinder(radius: d * 0.05, height: d * 1.4)
        // learning — instruments
        case .compass:        return SCNTorus(ringRadius: d * 0.5, pipeRadius: d * 0.1)
        case .telescope:      return SCNCylinder(radius: d * 0.16, height: d * 1.1)
        case .mapFin:         return SCNBox(width: d * 0.1, height: d * 0.8, length: d * 1.0, chamferRadius: d * 0.05)
        // aesthetic — prisms and chimes
        case .prism:          return SCNPyramid(width: d * 0.7, height: d * 1.0, length: d * 0.7)
        case .chime:          return SCNCapsule(capRadius: d * 0.1, height: d * 1.1)
        }
    }

    /// The material's color, from the theme tokens (skin-aware).
    static func color(_ mat: PartMaterial, _ tokens: ThemeTokens) -> Color {
        switch mat {
        case .glass:  return tokens.accent
        case .brass:  return tokens.accentText
        case .light:  return tokens.accentSoft
        case .cloth:  return tokens.surfaceSoft
        case .wood:   return tokens.textMuted
        case .paper:  return tokens.surface
        }
    }

    /// Configure a part's material — one place, so stage + keepsake match.
    static func apply(_ m: SCNMaterial, kind: PartKind, glow: Double, tokens: ThemeTokens) {
        let mat = kind.material
        m.diffuse.contents = StageColor(color(mat, tokens))
        m.lightingModel = .physicallyBased
        m.isDoubleSided = true
        switch mat {
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
        if glow > 0 {
            m.emission.contents = StageColor(tokens.accentSoft)
            m.emission.intensity = CGFloat(glow)
        }
    }
}
