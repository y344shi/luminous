//
//  LateNightCareOrbit.swift
//  Luminous — late-night get-home care as GUIDING STARS, not a banner.
//
//  When it's late and you're out, a few care bubbles shoot in and gently orbit
//  the glass — the way everything else in the planetarium behaves. The station
//  star carries an arrow that points the real-world way to it. Warm, offering,
//  never commanding; the late-night safety copy stays code-owned. Reuses the
//  pure, tested LateNightCare helpers.
//

import SwiftUI
import MapKit
import CoreLocation
#if os(iOS)
import UIKit
#endif

struct LateNightCareOrbit: View {
    let center: CGPoint
    let size: CGSize

    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One guiding star.
    private struct Care: Identifiable {
        let id: String
        let emoji: String
        let title: String
        let arrow: Double?          // radians — only the station points a way
        let run: () -> Void
    }

    @State private var bornDate: Date?
    @State private var sense = SituationSense()

    var body: some View {
        let actions = careActions
        ZStack {
            if let line = sense.read?.line {
                Text(line)
                    .font(.system(size: 13)).lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: 260)
                    .position(x: center.x, y: max(90, center.y - 168))
            }
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let born = bornDate?.timeIntervalSinceReferenceDate ?? t
                ForEach(Array(actions.enumerated()), id: \.element.id) { i, a in
                    let p = position(i, count: actions.count, t: t, born: born)
                    careStar(a).position(p)
                }
            }
        }
        .onAppear {
            if bornDate == nil { bornDate = Date() }
            refreshSituation()
        }
        .onDisappear { bornDate = nil }
    }

    private func refreshSituation() {
        sense.refreshIfStale(
            hour: Calendar.current.component(.hour, from: Date()),
            surroundings: sensed.surroundings,
            hasStation: sensed.nearestTransit != nil,
            stationDist: sensed.nearestTransit?.distanceLabel,
            homeKnown: homeCoord != nil,
            weather: sensed.weatherKind?.rawValue)
    }

    // MARK: layout — a slow ring around the glass, with a shoot-in

    private func position(_ i: Int, count: Int, t: TimeInterval, born: TimeInterval) -> CGPoint {
        let R: CGFloat = 122
        let ell: CGFloat = 0.66
        let base = -Double.pi / 2 + 2 * Double.pi / Double(max(count, 1)) * Double(i)
        let omega = 2 * Double.pi / 42.0
        let ang = reduceMotion ? base : base + t * omega
        let slot = CGPoint(x: center.x + CGFloat(cos(ang)) * R,
                           y: center.y + CGFloat(sin(ang)) * R * ell)
        let age = reduceMotion ? 9 : (t - born)
        if age < 0.9 {                                   // shoot in from the edge
            let e = 1 - pow(1 - age / 0.9, 3)            // easeOut
            let startR = Double(max(size.width, size.height))
            let start = CGPoint(x: center.x + CGFloat(cos(ang) * startR),
                                y: center.y + CGFloat(sin(ang) * startR) * ell)
            return CGPoint(x: start.x + (slot.x - start.x) * CGFloat(e),
                           y: start.y + (slot.y - start.y) * CGFloat(e))
        }
        return slot
    }

    // MARK: a guiding star

    private func careStar(_ a: Care) -> some View {
        Button { a.run() } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(RadialGradient(
                        colors: [theme.surface.opacity(0.95), theme.accentSoft.opacity(0.6),
                                 theme.surfaceSoft.opacity(0.3)],
                        center: UnitPoint(x: 0.34, y: 0.30), startRadius: 0, endRadius: 30))
                    Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1)
                    if let arrow = a.arrow {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(theme.accentText)
                            .rotationEffect(.radians(arrow))
                    } else {
                        Text(a.emoji).font(.system(size: 20))
                    }
                }
                .frame(width: 48, height: 48)
                .shadow(color: theme.accent.opacity(0.35), radius: 7)
                Text(a.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: the actions

    /// The guiding stars — built from the model's chosen intents (with a
    /// deterministic fallback), never inventing an unavailable action.
    private var careActions: [Care] {
        if !store.senseAround {
            return [Care(id: "enable", emoji: "📍", title: "帮我看路", arrow: nil) {
                store.setSenseAround(true); sensed.start(enabled: true)
            }]
        }
        let intents = sense.read?.intents
            ?? SituationCare.fallback(hasStation: sensed.nearestTransit != nil,
                                      homeKnown: homeCoord != nil).intents
        var out: [Care] = []
        for intent in intents {
            switch intent {
            case .transit:
                if let station = sensed.nearestTransit {
                    out.append(Care(id: "station", emoji: "🚇",
                                    title: "车站 · \(station.distanceLabel)",
                                    arrow: arrowAngle(to: station)) { station.mapItem.openInMaps() })
                }
            case .goHome:
                if homeCoord != nil {
                    out.append(Care(id: "home", emoji: "🏠", title: "回家的路", arrow: nil) { openRouteHome() })
                }
            case .cab:
                out.append(Care(id: "cab", emoji: "🚕", title: "叫一辆车", arrow: nil) { openCab() })
            case .water:
                out.append(Care(id: "water", emoji: "💧", title: "喝口温水", arrow: nil) {})
            case .rest:
                out.append(Care(id: "rest", emoji: "🌙", title: "就地歇一会", arrow: nil) {})
            }
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }   // dedupe, keep order
    }

    // MARK: geometry + openers (reuse the pure helpers)

    private var homeCoord: (lat: Double, lon: Double)? {
        guard let cell = store.learnedPlaceCells().home else { return nil }
        return LateNightCare.coordinate(fromCellKey: cell)
    }

    private func arrowAngle(to place: NearbyPlace) -> Double {
        guard let here = sensed.coordinate,
              let dest = place.mapItem.placemark.location?.coordinate else { return 0 }
        let bearing = LateNightCare.bearing(fromLat: here.latitude, lon: here.longitude,
                                            toLat: dest.latitude, lon: dest.longitude)
        return LateNightCare.arrowAngle(bearingRadians: bearing, headingDegrees: sensed.heading)
    }

    private func openRouteHome() {
        guard let h = homeCoord else { return }
        LateNightActions.openRouteHome(lat: h.lat, lon: h.lon)
    }

    private func openCab() {
        LateNightActions.openCab(homeLat: homeCoord?.lat, homeLon: homeCoord?.lon)
    }
}
