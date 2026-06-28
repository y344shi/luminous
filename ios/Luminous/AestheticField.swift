//
//  AestheticField.swift
//  Luminous
//
//  The backdrop View for the active skin. Kept separate from the `Aesthetic`
//  enum so lighter targets (watchOS) can reuse the enum without pulling in the
//  heavy field views (Canvas / MeshGradient). iOS + macOS only.
//

import SwiftUI

/// Renders the backdrop field for the active skin. Reads the live choice from
/// the store, so switching the skin in Settings re-skins Home immediately.
struct AestheticField: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.aesthetic {
        case .glass: ZStack { SceneBackground(); GlassField() }
        case .ocean: ZStack { SceneBackground(); OceanField() }
        case .paper: PaperField()
        }
    }
}
