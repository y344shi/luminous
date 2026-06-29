//
//  SceneBackground.swift
//  Luminous — the living world behind Home
//
//  Instead of abstract bubbles, the glass / ocean skins show a calm environment
//  graded by the real time of day — its **lighting** included: a sky that shifts
//  dawn → noon → dusk → night, a soft sun (or moon + stars at night) that sits
//  where it would in the sky right now, and — for the ocean skin — water below
//  the horizon catching the light. Still by design (no distracting motion).
//
//  `DayGrade` supplies the palette; this is the closest the iOS app gets to the
//  web's sensed scene until the full sensing fusion is ported.
//

import SwiftUI

enum SceneMode { case sky, sea }

struct SceneBackground: View {
    var mode: SceneMode = .sky
    var hour: Int = Calendar.current.component(.hour, from: Date())
    /// Sensed weather — tints the sky toward overcast / fog when present.
    var weather: WeatherKind? = nil

    private var isNight: Bool { DayGrade.phase(hour: hour) == .night }
    private var isOvercast: Bool { weather == .clouds || weather == .rain || weather == .fog || weather == .snow }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let sky = DayGrade.colors(hour: hour)   // [top, horizon, ground]
            let light = lightColor
            let lp = lightPoint
            let horizonY = mode == .sea ? size.height * 0.52 : size.height

            ZStack {
                // 1) the sky, graded by the hour's lighting
                LinearGradient(
                    gradient: Gradient(colors: [sky[0], sky[0], sky[1], sky[2]]),
                    startPoint: .top, endPoint: .bottom)

                // 2) night stars (faint, static)
                if isNight { StarLayer().opacity(0.7) }

                // 3) the light source: a soft glow + a gentle disk
                RadialGradient(
                    gradient: Gradient(colors: [light.opacity(isNight ? 0.45 : 0.85), light.opacity(0)]),
                    center: lp, startRadius: 0, endRadius: size.width * (isNight ? 0.40 : 0.70))
                    .blendMode(.plusLighter)
                Circle()
                    .fill(light.opacity(isNight ? 0.6 : 0.95))
                    .frame(width: isNight ? 28 : 46, height: isNight ? 28 : 46)
                    .blur(radius: isNight ? 3 : 6)
                    .position(x: lp.x * size.width, y: lp.y * size.height)

                // 4) ocean: water below the horizon, catching the light
                if mode == .sea {
                    waterLayer(size: size, horizonY: horizonY, sky: sky, light: light, lp: lp)
                }

                // 4.5) sensed weather: soft overcast / fog veil + still clouds
                weatherOverlay(size: size)

                // 5) a soft vignette to settle the edges
                RadialGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.18)]),
                    center: .center, startRadius: size.height * 0.25, endRadius: size.height * 0.75)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Water (ocean skin)

    private func waterLayer(size: CGSize, horizonY: CGFloat, sky: [Color], light: Color, lp: UnitPoint) -> some View {
        let surface = isNight ? Color(hue: 0.58, saturation: 0.50, brightness: 0.30)
                              : Color(hue: 0.54, saturation: 0.44, brightness: 0.64)
        return ZStack(alignment: .top) {
            // clearly-water gradient: a teal surface catching the sky → deep below
            LinearGradient(
                gradient: Gradient(colors: [sky[1].opacity(0.55), surface, waterDeep]),
                startPoint: .top, endPoint: .bottom)
            // a soft column of reflected light under the sun/moon
            LinearGradient(
                gradient: Gradient(colors: [light.opacity(isNight ? 0.18 : 0.35), .clear]),
                startPoint: .top, endPoint: .bottom)
                .frame(width: size.width * 0.34)
                .blur(radius: 14)
                .position(x: lp.x * size.width, y: horizonY + (size.height - horizonY) * 0.45)
            // a bright horizon seam
            Rectangle()
                .fill(light.opacity(isNight ? 0.25 : 0.5))
                .frame(height: 2)
                .blur(radius: 3)
        }
        .frame(width: size.width, height: size.height - horizonY)
        .position(x: size.width / 2, y: horizonY + (size.height - horizonY) / 2)
    }

    // MARK: Weather (calm, still)

    @ViewBuilder private func weatherOverlay(size: CGSize) -> some View {
        switch weather {
        case .clouds:
            ZStack { clouds(size: size, opacity: 0.55); veil(.gray, 0.10) }
        case .rain:
            ZStack { clouds(size: size, opacity: 0.7); veil(.gray, 0.22) }
        case .fog:
            veil(.white, 0.22)
        case .snow:
            ZStack { clouds(size: size, opacity: 0.5); veil(.white, 0.16) }
        default:
            EmptyView()
        }
    }

    private func veil(_ color: Color, _ opacity: Double) -> some View {
        color.opacity(opacity)
    }

    /// A few soft, still cloud banks across the upper sky.
    private func clouds(size: CGSize, opacity: Double) -> some View {
        Canvas { ctx, sz in
            let bands: [(CGFloat, CGFloat, CGFloat)] = [
                (0.24, 0.22, 0.30), (0.66, 0.16, 0.34), (0.46, 0.34, 0.26),
            ]
            for (cx, cy, w) in bands {
                let rw = sz.width * w
                let rh = rw * 0.42
                let rect = CGRect(x: cx * sz.width - rw / 2, y: cy * sz.height - rh / 2, width: rw, height: rh)
                ctx.fill(Capsule().path(in: rect), with: .color(.white.opacity(opacity * 0.6)))
            }
        }
        .blur(radius: 18)
        .allowsHitTesting(false)
    }

    // MARK: Lighting

    /// Where the sun (day) or moon (night) sits, in unit coordinates. It rises
    /// in the east, peaks overhead near midday, and sets in the west.
    private var lightPoint: UnitPoint {
        if isNight {
            let h = hour < 6 ? hour + 24 : hour          // 18…30
            let f = (Double(h) - 18) / 12                // 0 at dusk … 1 at dawn
            let x = 0.22 + f * 0.56
            let y = 0.34 - sin(f * .pi) * 0.16           // a low arc
            return UnitPoint(x: x, y: max(0.08, y))
        } else {
            let f = min(max((Double(hour) - 6) / 12, 0), 1)  // 0 at dawn … 1 at dusk
            let x = 0.12 + f * 0.76                            // east → west
            let alt = max(0.03, sin(f * .pi))                 // low at dawn/dusk, high noon
            let y = 0.48 - alt * 0.34
            return UnitPoint(x: x, y: y)
        }
    }

    private var lightColor: Color {
        switch DayGrade.phase(hour: hour) {
        case .dawn:      return Color(hue: 0.06, saturation: 0.30, brightness: 1.0)
        case .morning:   return Color(hue: 0.12, saturation: 0.18, brightness: 1.0)
        case .noon:      return Color(hue: 0.13, saturation: 0.10, brightness: 1.0)
        case .afternoon: return Color(hue: 0.10, saturation: 0.22, brightness: 1.0)
        case .dusk:      return Color(hue: 0.04, saturation: 0.40, brightness: 1.0)
        case .night:     return Color(hue: 0.60, saturation: 0.14, brightness: 0.98)
        }
    }

    private var waterDeep: Color {
        isNight ? Color(hue: 0.60, saturation: 0.55, brightness: 0.16)
                : Color(hue: 0.55, saturation: 0.45, brightness: 0.42)
    }
}

/// A scatter of faint, fixed stars for the night sky.
private struct StarLayer: View {
    var body: some View {
        Canvas { ctx, size in
            for i in 0 ..< 60 {
                let fi = Double(i)
                let x = abs((sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)) * size.width
                let y = abs((sin(fi * 78.233) * 12543.123).truncatingRemainder(dividingBy: 1)) * size.height * 0.55
                let r = 0.6 + (fi.truncatingRemainder(dividingBy: 3)) * 0.5
                let a = 0.25 + (fi.truncatingRemainder(dividingBy: 5)) * 0.12
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("dusk sea") {
    SceneBackground(mode: .sea, hour: 19)
}
#Preview("noon sky") {
    SceneBackground(mode: .sky, hour: 12)
}
