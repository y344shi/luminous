//
//  LateNightActions.swift
//  Luminous — the get-home openers, shared by the glass orbit and the
//  ocean/paper strip. Maps / transit / cab; code-owned, safety-first.
//

import Foundation
import MapKit
import CoreLocation
#if os(iOS)
import UIKit
#endif

enum LateNightActions {

    static func openStation(_ place: NearbyPlace) {
        place.mapItem.openInMaps()
    }

    static func openRouteHome(lat: Double, lon: Double) {
        let item = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)))
        item.name = "家"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
    }

    static func openCab(homeLat: Double?, homeLon: Double?) {
        #if os(iOS)
        var s = "https://m.uber.com/ul/?action=setPickup&pickup=my_location"
        if let lat = homeLat, let lon = homeLon {
            s += "&dropoff[latitude]=\(lat)&dropoff[longitude]=\(lon)&dropoff[nickname]=家"
        }
        if let url = URL(string: s) { UIApplication.shared.open(url) }
        #endif
    }
}
