//
//  LateNightCareStrip.swift
//  Luminous — the get-home care for the ocean & paper skins: a compact top
//  strip (the glass skin uses the orbiting-stars version). Same actions, same
//  code-owned safety copy; a strip fits a list/liquid home better than an orbit.
//

import SwiftUI

struct LateNightCareStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme
    @State private var sense = SituationSense()

    private struct Chip: Identifiable { let id: String; let emoji: String; let title: String; let run: () -> Void }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sense.read?.line ?? "已经很晚了，回家的路我先帮你看着。")
                .font(.system(size: 13)).lineSpacing(2)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { c in
                        Button(action: c.run) {
                            HStack(spacing: 5) {
                                Text(c.emoji).font(.system(size: 13))
                                Text(c.title).font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(theme.accentText)
                            .padding(.horizontal, 11).padding(.vertical, 7)
                            .background(theme.accentSoft)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
        .onAppear {
            sense.refreshIfStale(
                hour: Calendar.current.component(.hour, from: Date()),
                surroundings: sensed.surroundings,
                hasStation: sensed.nearestTransit != nil,
                stationDist: sensed.nearestTransit?.distanceLabel,
                homeKnown: homeCoord != nil,
                weather: sensed.weatherKind?.rawValue)
        }
    }

    private var homeCoord: (lat: Double, lon: Double)? {
        guard let cell = store.learnedPlaceCells().home else { return nil }
        return LateNightCare.coordinate(fromCellKey: cell)
    }

    private var chips: [Chip] {
        if !store.senseAround {
            return [Chip(id: "enable", emoji: "📍", title: "帮我看路") {
                store.setSenseAround(true); sensed.start(enabled: true)
            }]
        }
        let intents = sense.read?.intents
            ?? SituationCare.fallback(hasStation: sensed.nearestTransit != nil,
                                      homeKnown: homeCoord != nil).intents
        var out: [Chip] = []
        for intent in intents {
            switch intent {
            case .transit:
                if let s = sensed.nearestTransit {
                    out.append(Chip(id: "station", emoji: "🚇", title: "车站 · \(s.distanceLabel)") {
                        LateNightActions.openStation(s)
                    })
                }
            case .goHome:
                if let h = homeCoord {
                    out.append(Chip(id: "home", emoji: "🏠", title: "回家的路") {
                        LateNightActions.openRouteHome(lat: h.lat, lon: h.lon)
                    })
                }
            case .cab:
                out.append(Chip(id: "cab", emoji: "🚕", title: "叫一辆车") {
                    LateNightActions.openCab(homeLat: homeCoord?.lat, homeLon: homeCoord?.lon)
                })
            case .water:
                out.append(Chip(id: "water", emoji: "💧", title: "喝口温水") {})
            case .rest:
                out.append(Chip(id: "rest", emoji: "🌙", title: "就地歇一会") {})
            }
        }
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }
    }
}
