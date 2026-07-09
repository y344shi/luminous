//
//  Sensors.swift
//  Luminous — on-device sensing (mirrors @core/sensors + the platform samplers)
//
//  Two halves, per docs/INTEGRATION.md:
//  • Pure classifiers (shared rules, ported verbatim from @core/sensors) — testable.
//  • A platform sampler (`SensedSignals`) that reads raw device signals, derives a
//    COARSE classification, and forgets the raw. Nothing raw is stored or sent.
//    (Weather sends only an already-coarsened home coordinate to open-meteo.)
//
//  Heart-rate → arousal (HealthKit) and mic loudness are stubbed for a real device;
//  motion + location run here. Everything degrades to nil when unavailable.
//

import Foundation
import CoreGraphics
import CoreLocation
import MapKit
#if os(iOS)
import CoreMotion
#endif

/// A nearby place from MapKit (cafe / store / market …), for the Home "附近" row.
struct NearbyPlace: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let distanceM: Double
    let mapItem: MKMapItem

    var distanceLabel: String {
        distanceM < 1000
            ? "\(Int((distanceM / 50).rounded()) * 50)m"
            : String(format: "%.1fkm", distanceM / 1000)
    }

    /// The coarse kind, for matching a wish to a fitting place.
    var kind: PlaceKind? { SensedSignals.placeKind(mapItem.pointOfInterestCategory) }
}

// Pure classifiers (enum Sensors) + Weather mapping live in SensorClassifiers.swift
// (Foundation-only, shared with the SwiftPM test package).

// MARK: - Platform sampler

/// Samples coarse on-device signals and publishes the derived classifications.
/// Observable so views re-rank when a sense changes. Opt-in via `start(enabled:)`.
@MainActor
@Observable
final class SensedSignals: NSObject, CLLocationManagerDelegate {
    var activity: Activity?
    var locationHint: LocationType?
    var weatherKind: WeatherKind?
    var isOutdoorWeatherGood: Bool?

    /// Device tilt as a unit vector (x: left/right, y: forward/back), for the
    /// gentle "gravity" lean of the floating wishes. Zero on the simulator.
    var gravity: CGSize = .zero

    /// Last coarse coordinate (for weather + nearby search).
    var coordinate: CLLocationCoordinate2D?
    /// Nearby cafes / stores / markets for the Home "附近" row.
    var nearby: [NearbyPlace] = []

    /// The nearest transit station (subway / bus / rail) — for the late-night
    /// "get home" care. Kept apart from `nearby` (a safety place, not a wish place).
    var nearestTransit: NearbyPlace?

    /// Compass heading in degrees (magnetic, 0 = north), so the on-screen arrow
    /// can point the real-world way to the station. nil where unavailable (sim).
    var heading: Double?

    /// The coarse ~150m grid cell we're in right now (never a raw coordinate).
    var currentCell: String?
    /// Learned anchors (home = modal night cell, work = weekday-day cell),
    /// computed from the event log and handed in by RootView.
    var homeCell: String?
    var workCell: String?

    /// Coarse "a cafe is right here" — gently lifts a coffee/connection wish.
    var nearbyCafe: Bool {
        nearby.contains { $0.distanceM < 300 && $0.mapItem.pointOfInterestCategory == .cafe }
    }
    /// Coarse "shops/market within a short walk" — lifts an errand/outing wish.
    var nearbyOuting: Bool {
        nearby.contains {
            $0.distanceM < 400 &&
            [.foodMarket, .store, .bakery, .restaurant].contains($0.mapItem.pointOfInterestCategory)
        }
    }

    /// Kinds of places within a short walk (≤600m) — feeds `placeBonus`.
    var nearbyKinds: [PlaceKind] {
        Array(Set(nearby.filter { $0.distanceM < 600 }.compactMap { $0.kind }))
    }

    private let manager = CLLocationManager()
    private var enabled = false
    private var weatherFetchedAt: Date?
    private var refreshTimer: Timer?
    private var lastFixAt: Date?
    private var lastNearbyAt: Date?
    private var lastNearbyLoc: CLLocation?

    #if os(iOS)
    private let motion = CMMotionManager()
    private let activityManager = CMMotionActivityManager()
    private var magnitudes: [Double] = []
    #endif

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced  // coarse only
    }

    /// Start sensing. Motion is permission-free; location asks when enabled.
    /// While the app is in the foreground, a gentle timer re-senses every 5
    /// minutes so the day's rhythm is real, not a single snapshot.
    func start(enabled: Bool) {
        self.enabled = enabled
        startMotion()
        refreshTimer?.invalidate()
        refreshTimer = nil
        guard enabled else { return }
        #if os(iOS) || os(watchOS)
        manager.requestWhenInUseAuthorization()
        #endif
        manager.requestLocation()
        lastFixAt = Date()
        #if os(iOS)
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        #endif
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// One coarse re-sense (foreground return, timer tick). Throttled to ≥60 s.
    func refresh() {
        guard enabled else { return }
        if let last = lastFixAt, Date().timeIntervalSince(last) < 60 { return }
        lastFixAt = Date()
        manager.requestLocation()
    }

    private func startMotion() {
        #if os(iOS)
        // Primary: CoreMotion's high-level activity classifier (stationary /
        // walking / automotive) — reliable on device. Needs Motion permission.
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] act in
                guard let self, let act, act.confidence != .low else { return }
                if act.stationary { self.activity = .still }
                else if act.automotive { self.activity = .transit }
                else if act.walking || act.running || act.cycling { self.activity = .walking }
            }
        }
        // Device tilt → a gentle "gravity" vector for the floating wishes.
        if motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive {
            motion.deviceMotionUpdateInterval = 0.08
            motion.startDeviceMotionUpdates(to: .main) { [weak self] dm, _ in
                guard let self, let g = dm?.gravity else { return }
                self.gravity = CGSize(width: g.x, height: g.y)
            }
        }
        // Fallback: raw accelerometer → classifyActivity (matches @core), used when
        // the activity classifier is unavailable (e.g. simulator).
        if motion.isAccelerometerAvailable, !motion.isAccelerometerActive {
            motion.accelerometerUpdateInterval = 0.2
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, self.activity == nil, let a = data?.acceleration else { return }
                let m = sqrt(a.x * a.x + a.y * a.y + a.z * a.z) * 9.81
                self.magnitudes.append(m)
                if self.magnitudes.count > 20 { self.magnitudes.removeFirst() }
                if let act = Sensors.classifyActivity(self.magnitudes) { self.activity = act }
            }
        }
        #endif
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        let coord = loc.coordinate
        Task { @MainActor in
            self.coordinate = coord
            self.currentCell = Places.cellKey(lat: coord.latitude, lon: coord.longitude)
            self.locationHint = Places.hint(currentCell: self.currentCell,
                                            home: self.homeCell, work: self.workCell,
                                            activity: self.activity)
            await self.fetchWeather(lat: coord.latitude, lon: coord.longitude)
            // Re-search POIs only when we actually moved (>250m) or it's stale
            // (>15 min) — kind to MapKit, fresh enough for the scout.
            let moved = self.lastNearbyLoc.map { loc.distance(from: $0) > 250 } ?? true
            let stale = self.lastNearbyAt.map { Date().timeIntervalSince($0) > 900 } ?? true
            if moved || stale {
                self.lastNearbyLoc = loc
                self.lastNearbyAt = Date()
                await self.fetchNearby(center: coord)
                await self.fetchNearestTransit(center: coord)
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        // Silent: sensing degrades to nil, never nags.
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let deg = newHeading.magneticHeading
        guard deg >= 0 else { return }   // negative = invalid
        Task { @MainActor in self.heading = deg }
    }

    // MARK: Nearby places (MapKit local search)

    private func fetchNearby(center: CLLocationCoordinate2D) async {
        let req = MKLocalPointsOfInterestRequest(center: center, radius: 2000)
        req.pointOfInterestFilter = MKPointOfInterestFilter(including:
            [.cafe, .restaurant, .bakery, .foodMarket, .store, .pharmacy,
             .library, .park, .museum, .fitnessCenter,
             // the world is more than shops: attractions + the bigger outdoors
             .theater, .movieTheater, .aquarium, .zoo, .amusementPark, .stadium,
             .beach, .nationalPark, .campground, .marina, .winery, .brewery])
        do {
            let resp = try await MKLocalSearch(request: req).start()
            let here = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let places = resp.mapItems.compactMap { item -> NearbyPlace? in
                guard let loc = item.placemark.location, let name = item.name else { return nil }
                return NearbyPlace(
                    name: name,
                    emoji: Self.emoji(for: item.pointOfInterestCategory),
                    distanceM: loc.distance(from: here),
                    mapItem: item)
            }
            .sorted { $0.distanceM < $1.distanceM }
            // Kind-diverse retention: nearest-first but at most 2 per kind, so a
            // plaza of 12 shops can't crowd out the park and the theater.
            var kept: [NearbyPlace] = []
            var perKind: [PlaceKind: Int] = [:]
            for p in places {
                guard let k = p.kind else { continue }
                if perKind[k, default: 0] < 2 {
                    kept.append(p)
                    perKind[k, default: 0] += 1
                }
                if kept.count == 14 { break }
            }
            self.nearby = kept
        } catch {
            // leave nearby as-is on failure
        }
    }

    /// The nearest transit station — its own search so it isn't crowded out by
    /// the kind-diverse `nearby` retention. Feeds the late-night "get home" care.
    private func fetchNearestTransit(center: CLLocationCoordinate2D) async {
        let req = MKLocalPointsOfInterestRequest(center: center, radius: 2500)
        req.pointOfInterestFilter = MKPointOfInterestFilter(including: [.publicTransport])
        do {
            let resp = try await MKLocalSearch(request: req).start()
            let here = CLLocation(latitude: center.latitude, longitude: center.longitude)
            self.nearestTransit = resp.mapItems.compactMap { item -> NearbyPlace? in
                guard let loc = item.placemark.location, let name = item.name else { return nil }
                return NearbyPlace(name: name, emoji: "🚇",
                                   distanceM: loc.distance(from: here), mapItem: item)
            }
            .min { $0.distanceM < $1.distanceM }
        } catch {
            // leave as-is on failure
        }
    }

    static func emoji(for cat: MKPointOfInterestCategory?) -> String {
        switch cat {
        case .some(.publicTransport): return "🚇"
        default: break
        }
        return emojiPlace(for: cat)
    }

    private static func emojiPlace(for cat: MKPointOfInterestCategory?) -> String {
        switch cat {
        case .some(.cafe):         return "☕"
        case .some(.restaurant):   return "🍴"
        case .some(.bakery):       return "🥐"
        case .some(.foodMarket):   return "🛒"
        case .some(.store):        return "🛍️"
        case .some(.pharmacy):     return "💊"
        case .some(.library):      return "📚"
        case .some(.park):         return "🌳"
        case .some(.museum):       return "🖼️"
        case .some(.fitnessCenter): return "🏋️"
        case .some(.theater):      return "🎭"
        case .some(.movieTheater): return "🎬"
        case .some(.aquarium):     return "🐠"
        case .some(.zoo):          return "🦒"
        case .some(.amusementPark): return "🎡"
        case .some(.stadium):      return "🏟️"
        case .some(.beach):        return "🏖️"
        case .some(.nationalPark): return "🏞️"
        case .some(.campground):   return "🏕️"
        case .some(.marina):       return "⛵"
        case .some(.winery), .some(.brewery): return "🍷"
        default:                   return "📍"
        }
    }

    /// Map a MapKit POI category to our coarse `PlaceKind`.
    static func placeKind(_ cat: MKPointOfInterestCategory?) -> PlaceKind? {
        switch cat {
        case .some(.cafe), .some(.bakery): return .cafe
        case .some(.restaurant):           return .restaurant
        case .some(.foodMarket):           return .market
        case .some(.store), .some(.pharmacy): return .store
        case .some(.library):              return .library
        case .some(.park):                 return .park
        case .some(.museum):               return .museum
        case .some(.theater), .some(.movieTheater), .some(.aquarium), .some(.zoo),
             .some(.amusementPark), .some(.stadium), .some(.winery), .some(.brewery):
            return .attraction
        case .some(.beach), .some(.nationalPark), .some(.campground), .some(.marina):
            return .nature
        case .some(.fitnessCenter):        return .gym
        default:                           return nil
        }
    }

    // MARK: Weather (open-meteo, key-free; only a coarse coord leaves the device)

    private func fetchWeather(lat: Double, lon: Double) async {
        // round to ~city precision before it leaves the device (privacy contract)
        let rlat = (lat * 100).rounded() / 100
        let rlon = (lon * 100).rounded() / 100
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(rlat)&longitude=\(rlon)&current=weather_code,temperature_2m"
        guard let url = URL(string: urlStr) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteo.self, from: data)
            let kind = Weather.classify(code: decoded.current.weather_code)
            self.weatherKind = kind
            self.isOutdoorWeatherGood = Weather.isGoodOutdoor(kind: kind, tempC: decoded.current.temperature_2m)
        } catch {
            // network/coarse failure → leave weather nil
        }
    }
}

private struct OpenMeteo: Decodable {
    struct Current: Decodable { let weather_code: Int; let temperature_2m: Double }
    let current: Current
}
