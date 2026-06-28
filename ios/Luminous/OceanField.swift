//
//  OceanField.swift
//  Luminous — skin · Ocean
//
//  A buoyancy variant of `GlassField`. Same TimelineView + Canvas technique,
//  same `GlassBubble` model and draw helpers — only the motion changes:
//  the bottom edge reads as the ocean floor and bubbles float UP toward the
//  surface (top). The most relevant (highest depth) settle highest, and every
//  bubble bobs gently. Reduce Motion is honored by the shared field.
//

import SwiftUI

struct OceanField: View {
    var bubbles: [GlassBubble] = GlassBubble.field

    var body: some View {
        GlassField(bubbles: bubbles, buoyancy: true)
    }
}

#Preview {
    OceanField()
        .environment(\.theme, Theme.tokens(for: .duskGarden))
}
