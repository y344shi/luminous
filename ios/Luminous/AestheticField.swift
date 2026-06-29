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
    @Environment(\.colorScheme) private var colorScheme

    /// The sensed weather, when available — tints the sky (clouds / rain / fog).
    var weather: WeatherKind? = nil

    var body: some View {
        switch store.effectiveAesthetic(dark: colorScheme == .dark) {
        case .glass: SceneBackground(mode: .sky, weather: weather)   // open sky, lit by the hour
        case .ocean: SceneBackground(mode: .sea, weather: weather)   // sky + water catching the light
        case .paper: PaperField()
        }
    }
}
