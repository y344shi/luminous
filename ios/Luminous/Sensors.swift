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
}

// MARK: - Pure classifiers (verbatim from @core/sensors)

enum Sensors {
    /// magnitudes → still | walking | transit (mean-abs-deviation; needs ≥4 samples).
    static func classifyActivity(_ magnitudes: [Double]) -> Activity? {
        guard magnitudes.count >= 4 else { return nil }
        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let mad = magnitudes.reduce(0) { $0 + abs($1 - mean) } / Double(magnitudes.count)
        if mad < 0.6 { return .still }
        if mad < 3.5 { return .walking }
        return .transit
    }

    /// rms → quiet | lively (`rms >= 0.08` → lively).
    static func classifyAmbient(_ rms: Double) -> Ambient {
        rms >= 0.08 ? .lively : .quiet
    }

    /// bpm → calm | elevated (`bpm >= resting + 18` → elevated).
    static func classifyArousal(_ bpm: Double, resting: Double = 70) -> Arousal {
        bpm >= resting + 18 ? .elevated : .calm
    }
}

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

    private let manager = CLLocationManager()
    private var enabled = false
    private var weatherFetchedAt: Date?

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
    func start(enabled: Bool) {
        self.enabled = enabled
        startMotion()
        guard enabled else { return }
        #if os(iOS) || os(watchOS)
        manager.requestWhenInUseAuthorization()
        #endif
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
            self.locationHint = .outdoor  // coarse default; refined by saved-home later
            await self.fetchWeather(lat: coord.latitude, lon: coord.longitude)
            await self.fetchNearby(center: coord)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        // Silent: sensing degrades to nil, never nags.
    }

    // MARK: Nearby places (MapKit local search)

    private func fetchNearby(center: CLLocationCoordinate2D) async {
        let req = MKLocalPointsOfInterestRequest(center: center, radius: 2000)
        req.pointOfInterestFilter = MKPointOfInterestFilter(including:
            [.cafe, .restaurant, .bakery, .foodMarket, .store, .pharmacy])
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
            self.nearby = Array(places.prefix(6))
        } catch {
            // leave nearby as-is on failure
        }
    }

    static func emoji(for cat: MKPointOfInterestCategory?) -> String {
        switch cat {
        case .some(.cafe):       return "☕"
        case .some(.restaurant): return "🍴"
        case .some(.bakery):     return "🥐"
        case .some(.foodMarket): return "🛒"
        case .some(.store):      return "🛍️"
        case .some(.pharmacy):   return "💊"
        default:                 return "📍"
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

// MARK: - Weather mapping (mirrors @core/weather)

enum Weather {
    /// open-meteo WMO weather code → coarse kind.
    static func classify(code: Int) -> WeatherKind {
        switch code {
        case 0, 1:           return .clear
        case 2, 3:           return .clouds
        case 45, 48:         return .fog
        case 51...67, 80...82, 95...99: return .rain
        case 71...77, 85, 86: return .snow
        default:             return .unknown
        }
    }

    /// Good to be outside: clear/cloudy and mild.
    static func isGoodOutdoor(kind: WeatherKind, tempC: Double) -> Bool {
        (kind == .clear || kind == .clouds) && tempC >= 8 && tempC <= 30
    }
}

private struct OpenMeteo: Decodable {
    struct Current: Decodable { let weather_code: Int; let temperature_2m: Double }
    let current: Current
}
