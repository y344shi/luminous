//
//  RouteFinder.swift
//  Luminous — a real walking route to the place a step suggests
//
//  MKDirections, walking mode, from the coarse current coordinate. Degrades to
//  nil (the UI falls back to the straight-line distance it already shows).
//

import Foundation
import MapKit

enum RouteFinder {

    struct Walk: Hashable {
        let minutes: Int
        let meters: Int
        var label: String {
            meters < 1000 ? "步行约 \(max(minutes, 1)) 分钟 · \(meters)m"
                          : String(format: "步行约 %d 分钟 · %.1fkm", max(minutes, 1), Double(meters) / 1000)
        }
    }

    static func walking(to item: MKMapItem,
                        from coord: CLLocationCoordinate2D?) async -> Walk? {
        guard let coord else { return nil }
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        req.destination = item
        req.transportType = .walking
        guard let resp = try? await MKDirections(request: req).calculate(),
              let route = resp.routes.first else { return nil }
        return Walk(minutes: Int((route.expectedTravelTime / 60).rounded()),
                    meters: Int(route.distance.rounded()))
    }
}
