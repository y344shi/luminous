//
//  Domain.swift
//  Luminous — 《今天别消失》 / Today Don't Disappear
//
//  Core domain types, ported from the web app's framework-free `lib/`.
//  An AI life-anchor app: soft wishes (Seeds) → opportunities → traces.
//

import Foundation

// MARK: - Enums

enum SeedCategory: String, Codable, CaseIterable, Hashable {
    case body, creation, connection, exploration, recovery, learning, aesthetic
}

enum Energy: String, Codable, CaseIterable, Hashable {
    case low, medium, high
}

enum Mood: String, Codable, CaseIterable, Hashable {
    case empty, tired, anxious, okay, alive, avoidant, lonely
    case wantLove = "want_love"
    case unknown
}

enum SemanticTime: String, Codable, Hashable {
    case morning, lunch, afternoon
    case afterWork = "after_work"
    case evening
    case lateNight = "late_night"
    case weekend, transit
}

enum LocationType: String, Codable, CaseIterable, Hashable {
    case anywhere, home, work, outdoor, downtown, computer, transit, unknown
}

enum SeedStatus: String, Codable, Hashable {
    case active, sleeping, completed, archived
}

// MARK: - Sensed signals (mirror @core/sensors + @core/weather)

/// Coarse motion state derived on-device from the accelerometer.
enum Activity: String, Codable, Hashable { case still, walking, transit }

/// Coarse loudness derived on-device from the mic (never recorded).
enum Ambient: String, Codable, Hashable { case quiet, lively }

/// Coarse arousal derived on-device from heart rate (HealthKit).
enum Arousal: String, Codable, Hashable { case calm, elevated }

/// Coarse weather kind from open-meteo (only a coarsened home coord leaves device).
enum WeatherKind: String, Codable, Hashable { case clear, clouds, rain, snow, fog, unknown }

/// A coarse kind of nearby place — used to do a wish *somewhere that fits*
/// (learn French at a library/cafe; walk in a park; an errand at a store).
enum PlaceKind: String, Codable, Hashable, CaseIterable {
    case cafe, library, park, market, store, restaurant, gym, museum
    /// Theaters, cinemas, zoos, aquariums, stadiums — somewhere to be delighted.
    case attraction
    /// Beaches, national parks, campgrounds, marinas — the bigger outdoors.
    case nature
}

enum ThemeName: String, Codable, CaseIterable, Hashable {
    case warmPaper = "warm_paper"
    case duskGarden = "dusk_garden"
    case minimalIos = "minimal_ios"
    case fieldNotebook = "field_notebook"
    case softRitual = "soft_ritual"
}

// MARK: - Models

struct Seed: Codable, Identifiable, Hashable {
    var id: String
    var rawText: String
    var title: String
    var description: String?

    var categories: [SeedCategory]
    var minimumAction: String
    var estimatedDurationMin: Int
    var energyRequired: Energy
    var locationType: LocationType
    var preferredTimes: [SemanticTime]
    var triggerConditions: [String]

    var status: SeedStatus

    var createdAt: String
    var updatedAt: String
}

struct DeviceContext: Codable, Hashable {
    var isMobile: Bool
    var isAtComputer: Bool?
}

struct ContextSnapshot: Codable, Hashable {
    var timestamp: String
    var semanticTime: SemanticTime

    var mood: Mood
    var energy: Energy
    var freeMinutes: Int?

    var isLateNight: Bool
    var isWeekend: Bool?
    var isOutdoorWeatherGood: Bool?

    var locationHint: LocationType?

    var deviceContext: DeviceContext?

    // Sensed (on-device, all optional — degrade to nil when unavailable).
    var activity: Activity?
    var ambient: Ambient?
    var arousal: Arousal?
    var weatherKind: WeatherKind?

    /// Kinds of places within a short walk right now (cafe / library / park …).
    var nearbyKinds: [PlaceKind]?
}

struct Opportunity: Codable, Identifiable, Hashable {
    var id: String
    var seedId: String
    var score: Double
    var reason: String
    var suggestedAction: String
    var notificationText: String
    var createdAt: String
}

/// One thought kept on a pursuit's journal page (手帐) — an idea, a note, or a
/// suggestion the AI made that was worth keeping. Never a subtask.
struct PursuitNote: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case note, idea, aiIdea }
    var id: String
    var seedId: String
    var dateKey: String   // YYYY-MM-DD
    var kind: Kind
    var text: String

    init(seedId: String, kind: Kind = .note, text: String) {
        self.id = DomainUtil.uid("pnote")
        self.seedId = seedId
        self.dateKey = DomainUtil.localDateKey()
        self.kind = kind
        self.text = text
    }
}

struct DailyTrace: Codable, Identifiable, Hashable {
    var id: String
    var date: String // YYYY-MM-DD
    var seedId: String?
    var opportunityId: String?
    var text: String
    var category: SeedCategory?
    var partial: Bool?
    var createdAt: String
}

struct Settings: Codable, Hashable {
    var theme: ThemeName
    var aiMode: String // "mock" | "real"
    var quietHoursStart: Int
    var quietHoursEnd: Int
    var maxRemindersPerDay: Int
    var nudgesEnabled: Bool

    static let `default` = Settings(
        theme: .warmPaper,
        aiMode: "mock",
        quietHoursStart: 23,
        quietHoursEnd: 8,
        maxRemindersPerDay: 3,
        nudgesEnabled: false
    )
}

// MARK: - Shared helpers (port of lib/utils.ts)

enum DomainUtil {
    static func uid(_ prefix: String = "id") -> String {
        let rand = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        let time = String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
        return "\(prefix)_\(time)\(rand)"
    }

    static func nowIso() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    /// Local date as YYYY-MM-DD (not UTC) so "today" matches the user's day.
    static func localDateKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func clamp(_ n: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, n))
    }

    /// 今天 / 昨天 / 前天, else "M月D日" (year only when it differs from today).
    static func friendlyDate(_ dateKey: String, today: Date = Date()) -> String {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]) else {
            return dateKey
        }
        let cal = Calendar.current
        var comp = DateComponents(); comp.year = y; comp.month = mo; comp.day = d
        guard let date = cal.date(from: comp) else { return dateKey }
        let base = cal.startOfDay(for: today)
        let target = cal.startOfDay(for: date)
        let diff = cal.dateComponents([.day], from: target, to: base).day ?? 0
        if diff == 0 { return "今天" }
        if diff == 1 { return "昨天" }
        if diff == 2 { return "前天" }
        let md = "\(mo)月\(d)日"
        let todayYear = cal.component(.year, from: today)
        return y == todayYear ? md : "\(y)年\(md)"
    }
}
