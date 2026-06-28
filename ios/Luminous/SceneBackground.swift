//
//  SceneBackground.swift
//  Luminous — Direction B · Living World
//
//  A living scene wallpaper behind Home: a soft MeshGradient sky graded by the
//  real time of day (`DayGrade`), drifting slowly so the world feels alive.
//  iOS port of the web `lib/sceneBackground.ts` mesh-gradient scene.
//

import SwiftUI

struct SceneBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var hour: Int = Calendar.current.component(.hour, from: Date())

    var body: some View {
        let c = DayGrade.colors(hour: hour)
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            // gentle horizon sway — the middle row breathes left/right + up/down.
            let sx = Float(sin(t * 0.10)) * 0.05
            let sy = Float(cos(t * 0.08)) * 0.03

            MeshGradient(
                width: 3, height: 3,
                points: [
                    .init(0, 0),            .init(0.5, 0),            .init(1, 0),
                    .init(0, 0.5 + sy),     .init(0.5 + sx, 0.5),     .init(1, 0.5 - sy),
                    .init(0, 1),            .init(0.5, 1),            .init(1, 1),
                ],
                colors: [
                    c[0], c[0], c[1],
                    c[0], c[1], c[1],
                    c[1], c[2], c[2],
                ]
            )
            .overlay(softVignette)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var softVignette: some View {
        RadialGradient(
            gradient: Gradient(colors: [.clear, .black.opacity(0.12)]),
            center: .center, startRadius: 80, endRadius: 540)
    }
}

#Preview {
    ZStack {
        SceneBackground(hour: 19)
        Text("傍晚").font(.largeTitle).foregroundStyle(.white)
    }
}
