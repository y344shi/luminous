//
//  Aesthetic.swift
//  Luminous
//
//  A swappable "skin" system. A skin chooses the app's look — its backdrop
//  field and feel — without forking the core. Mirrors the web restructure:
//    glass → floating glass bubbles (Direction A · Liquid Glass)
//    ocean → the same field with buoyancy (bubbles rise toward the surface)
//    paper → a warm ruled-notebook home
//
//  Selection is intentionally a simple constant for now — no persistence.
//

import SwiftUI

/// The active visual skin. Swap `current` to re-skin the whole app.
enum Aesthetic: String, CaseIterable {
    case glass
    case ocean
    case paper

    /// The skin the app renders. Kept simple on purpose (no persistence yet).
    static var current: Aesthetic = .glass
}

/// Renders the backdrop field for the active skin. Drop this behind Home
/// content in place of a hard-coded `GlassField`.
struct AestheticField: View {
    var body: some View {
        switch Aesthetic.current {
        case .glass: GlassField()
        case .ocean: OceanField()
        case .paper: PaperField()
        }
    }
}
