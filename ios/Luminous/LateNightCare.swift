//
//  LateNightCare.swift
//  Luminous — the app's oldest promise, kept: catch you when it's late and out
//
//  Late night is the hard safety gate. When it's late AND the app can tell
//  you're away from home, it stops offering "do a little thing" and instead
//  helps you get home safely: the nearest station (with an arrow pointing the
//  way), the route home, a cab, a warm glass of water. This copy and these
//  rules are CODE-OWNED (the late-night gate lives in code, never a prompt),
//  and warm, never commanding — an offer, not an order.
//
//  Pure and Foundation-only (in the SwiftPM test package). Coordinates are
//  plain (lat, lon) doubles so the math stays testable; the view bridges to
//  CoreLocation.
//

import Foundation

enum LateNightCare {

    /// Bearing in RADIANS from point 1 to point 2 (0 = north, clockwise).
    static func bearing(fromLat lat1: Double, lon lon1: Double,
                        toLat lat2: Double, lon lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let y = sin(dLon) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dLon)
        return atan2(y, x)
    }

    /// Screen rotation (radians) for an arrow that points at the station,
    /// accounting for how the phone is held. `headingDegrees` nil → map-up
    /// (north is up), still a useful hint.
    static func arrowAngle(bearingRadians: Double, headingDegrees: Double?) -> Double {
        bearingRadians - (headingDegrees ?? 0) * .pi / 180
    }

    /// Offer get-home care? Late night AND we can tell they're OUT. At home →
    /// no (the gentle water/sleep stop-loss is enough); location unknown → no
    /// (never presume "out" without knowing).
    static func shouldOfferGettingHome(isLateNight: Bool, locationHint: LocationType?) -> Bool {
        guard isLateNight else { return false }
        switch locationHint {
        case .some(.home):            return false
        case .none, .some(.unknown):  return false
        default:                      return true   // work / outdoor / downtown / transit
        }
    }

    /// Parse a `Places` cell key ("45.4215,-75.6972") back to an approx coord
    /// (the learned home cell) for a route-home.
    static func coordinate(fromCellKey key: String) -> (lat: Double, lon: Double)? {
        let p = key.split(separator: ",")
        guard p.count == 2, let lat = Double(p[0]), let lon = Double(p[1]) else { return nil }
        return (lat, lon)
    }
}
