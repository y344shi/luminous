//
//  LateNightCareView.swift
//  Luminous — the calm "let's get you home" card, shown on Home when it's late
//  and you're out. Warm, offering, never commanding.
//

import SwiftUI
import MapKit
import CoreLocation
#if os(iOS)
import UIKit
#endif

struct LateNightCareView: View {
    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(headerLine)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !store.senseAround {
                enableSensingButton
            } else {
                if let station = sensed.nearestTransit {
                    stationRow(station)
                }
                if homeCoord != nil {
                    careRow("回家的路", system: "house") { openRouteHome() }
                }
                careRow("叫一辆车回家", system: "car") { openCab() }
                Text("如果还走不开，先给自己倒杯温水。")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private var headerLine: String {
        if !store.senseAround { return "已经很晚了。想让我帮你看看回家的路吗？" }
        if sensed.coordinate == nil { return "已经很晚了。我在看看你在哪儿…" }
        return "已经很晚了。回家的路，我先帮你看着。"
    }

    // MARK: rows

    private func stationRow(_ place: NearbyPlace) -> some View {
        Button { place.mapItem.openInMaps() } label: {
            HStack(spacing: Spacing.sm) {
                stationArrow(to: place)
                VStack(alignment: .leading, spacing: 1) {
                    Text("最近的车站 · \(place.name)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.textPrimary).lineLimit(1)
                    Text(place.distanceLabel + " · 往这边")
                        .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(Spacing.sm)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// An arrow that points the real-world way to the station (bearing minus the
    /// phone's heading; map-up when heading is unavailable).
    @ViewBuilder private func stationArrow(to place: NearbyPlace) -> some View {
        let angle = arrowAngle(to: place)
        ZStack {
            Circle().fill(theme.accentSoft).frame(width: 34, height: 34)
            Image(systemName: "location.north.fill")
                .font(.system(size: 15))
                .foregroundStyle(theme.accentText)
                .rotationEffect(.radians(angle))
        }
    }

    private func careRow(_ title: String, system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: system)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11))
                    .foregroundStyle(theme.textMuted)
            }
            .padding(Spacing.sm)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var enableSensingButton: some View {
        Button {
            store.setSenseAround(true)
            sensed.start(enabled: true)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "location")
                Text("打开「感受周围」，帮我看路")
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(theme.accentSoft)
            .foregroundStyle(theme.accentText)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: geometry + actions

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
        let item = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: h.lat, longitude: h.lon)))
        item.name = "家"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
    }

    private func openCab() {
        #if os(iOS)
        // Uber universal link — opens the app if installed, else mobile web.
        // Pre-fills the drop-off with home when we've learned it.
        var s = "https://m.uber.com/ul/?action=setPickup&pickup=my_location"
        if let h = homeCoord {
            s += "&dropoff[latitude]=\(h.lat)&dropoff[longitude]=\(h.lon)&dropoff[nickname]=家"
        }
        if let url = URL(string: s) { UIApplication.shared.open(url) }
        #endif
    }
}
