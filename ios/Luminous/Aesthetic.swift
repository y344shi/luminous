//
//  Aesthetic.swift
//  Luminous
//
//  A swappable "skin" system. A skin chooses the app's look — its backdrop
//  field and feel — without forking the core. Mirrors the web restructure
//  (lib/aesthetic.ts, Settings → 外观风格):
//    glass → floating glass bubbles (Direction A · Liquid Glass)
//    ocean → the same field with buoyancy (bubbles rise toward the surface)
//    paper → a warm ruled-notebook home
//
//  The active skin lives in `AppStore` (persisted), so it is switchable at
//  runtime from Settings on every platform — iOS, macOS and watchOS.
//

import SwiftUI

/// The active visual skin. Persisted in `AppStore.aesthetic`.
enum Aesthetic: String, CaseIterable, Codable, Identifiable, Hashable {
    case glass
    case ocean
    case paper

    var id: String { rawValue }

    /// The skin the app falls back to before any choice is made.
    static let fallback: Aesthetic = .glass

    /// Display name for the Settings skin picker.
    var label: String {
        switch self {
        case .glass: return "玻璃"
        case .ocean: return "海面"
        case .paper: return "纸页"
        }
    }

    /// One-line feeling, matched to the theme-picker voice.
    var feeling: String {
        switch self {
        case .glass: return "光里浮起来的几颗念头"
        case .ocean: return "念头从海底升上水面"
        case .paper: return "摊在桌上的一页暖纸"
        }
    }

    /// SF Symbol shown beside each skin in the picker.
    var symbol: String {
        switch self {
        case .glass: return "circle.hexagongrid"
        case .ocean: return "water.waves"
        case .paper: return "doc.text"
        }
    }
}
