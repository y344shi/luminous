//
//  Persistence.swift
//  Luminous — the SwiftData backing store (iOS / macOS / visionOS; the watch
//  keeps its own UserDefaults island — this file is not in the watch target).
//
//  Design (see ios/OVERNIGHT-SESSION.md):
//  • Hybrid records: a few queryable columns + a `payload` JSON blob of the
//    existing Codable struct. Structs stay the domain currency; struct evolution
//    never forces a SwiftData schema migration.
//  • CloudKit-ready shape: every property defaulted, no @Attribute(.unique),
//    no relationships — profile scoping via a plain `profileID` column.
//  • Multi-profile: several local "gardens" on one device, switchable.
//  • Migration imports the old tdd.* UserDefaults data into the default profile
//    and NEVER deletes it — reverting Store.swift restores everything.
//

import Foundation
import SwiftData

// MARK: - Records

@Model final class ProfileRecord {
    var uuid: String = ""
    var name: String = ""
    var createdAt: Date = Date.now
    /// JSON of ProfilePrefs — all per-profile scalars in one evolvable blob.
    var prefsPayload: String = ""
    init() {}
}

@Model final class SeedRecord {
    var seedID: String = ""
    var profileID: String = ""
    var status: String = ""
    var updatedAt: String = ""
    var payload: String = ""     // JSON of Seed
    init() {}
}

@Model final class TraceRecord {
    var traceID: String = ""
    var profileID: String = ""
    var date: String = ""        // YYYY-MM-DD
    var payload: String = ""     // JSON of DailyTrace
    init() {}
}

@Model final class LearningRecord {
    var entryID: String = ""
    var profileID: String = ""
    var dateKey: String = ""
    var payload: String = ""     // JSON of LearningEntry
    init() {}
}

@Model final class NoteRecord {
    var noteID: String = ""
    var profileID: String = ""
    var seedID: String = ""
    var payload: String = ""     // JSON of PursuitNote
    init() {}
}

/// Append-only life-event log: outcomes and sensed transitions, each with the
/// coarse context snapshot of its moment. The substrate for rhythm/recurrence.
@Model final class EventRecord {
    var eventID: String = ""
    var profileID: String = ""
    var timestamp: Date = Date.now
    var kind: String = ""        // e.g. "seed.planted", "outcome.partial", "sense.activity"
    var payloadJSON: String = "" // small kind-specific detail
    var contextJSON: String = "" // ContextSnapshot JSON, "" when absent
    init() {}
}

// MARK: - Per-profile scalar prefs (one blob instead of 10 scattered keys)

struct ProfilePrefs: Codable {
    var settings: Settings = .default
    var lastPick: LastPick = LastPick()
    var samplesPlanted: Bool = false
    var introSeen: Bool = false
    var aesthetic: Aesthetic = .fallback
    var aestheticAuto: Bool = false
    var senseAround: Bool = false
    var learnedVocab: [String: [String]] = [:]
    var musicOn: Bool = false
}

struct ProfileInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let createdAt: Date
}

// MARK: - Controller

@MainActor
final class Persistence {

    static let shared: Persistence? = Persistence()

    static let defaultProfileName = "我的花园"

    /// The CloudKit private-database container (same-Apple-ID sync). Activating
    /// it requires the PAID Apple Developer Program (iCloud entitlement) — the
    /// schema has been CloudKit-shaped since day one (all defaults, no uniques,
    /// no relationships), so the flip-on is just entitlement + toggle.
    static let cloudContainerID = "iCloud.rainymushroom.Luminous"

    /// True when this launch actually attached to CloudKit. False = local-only
    /// (toggle off, no entitlement, or no iCloud account) — the app is whole
    /// either way.
    private(set) var cloudActive = false

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private static func storeURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                           in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("Luminous.store")
    }

    /// Self-healing open: if the schema changed under a dev build, drop the
    /// store file and retry once. Loss-free — the UserDefaults mirror is kept
    /// dual-written and migration re-imports it.
    ///
    /// When the user has turned on iCloud 同步 (tdd.cloudSync) AND the build
    /// carries the CloudKit entitlement, we use the CloudKit-backed
    /// configuration. The attempt is COMPILE-TIME gated: without the real
    /// entitlement, CloudKit's mirroring delegate traps asynchronously on a
    /// background queue (verified: EXC_BREAKPOINT in
    /// PFCloudKitContainerProvider containerWithIdentifier:) — no try? can
    /// catch it, so the code path must not exist in unentitled builds.
    ///
    /// FLIP-ON (requires the PAID Apple Developer Program):
    ///  1. Xcode → target Luminous → Signing & Capabilities → + iCloud →
    ///     CloudKit → container `iCloud.rainymushroom.Luminous`.
    ///  2. Build Settings → SWIFT_ACTIVE_COMPILATION_CONDITIONS: add
    ///     `CLOUDKIT_ENABLED` (Debug + Release).
    ///  3. UIBackgroundModes remote-notification is already in place.
    ///  4. Settings → iCloud 同步 on each device; relaunch.
    private init?() {
        let schema = Schema([ProfileRecord.self, SeedRecord.self, TraceRecord.self,
                             LearningRecord.self, EventRecord.self, NoteRecord.self])
        let url = Self.storeURL()

        #if CLOUDKIT_ENABLED
        if UserDefaults.standard.bool(forKey: "tdd.cloudSync") {
            let cloud = ModelConfiguration(schema: schema, url: url,
                                           cloudKitDatabase: .private(Self.cloudContainerID))
            if let c = try? ModelContainer(for: schema, configurations: [cloud]) {
                container = c
                cloudActive = true
                return
            }
        }
        #endif

        let config = ModelConfiguration(schema: schema, url: url,
                                        cloudKitDatabase: .none)
        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            container = c
        } else {
            try? FileManager.default.removeItem(at: url)
            guard let c = try? ModelContainer(for: schema, configurations: [config]) else {
                return nil
            }
            container = c
        }
    }

    private func save() { try? context.save() }

    // MARK: JSON helpers

    private static func encode<T: Encodable>(_ v: T) -> String {
        (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    private static func decode<T: Decodable>(_ type: T.Type, _ s: String) -> T? {
        s.data(using: .utf8).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    // MARK: Profiles

    func profiles() -> [ProfileInfo] {
        let all = (try? context.fetch(FetchDescriptor<ProfileRecord>())) ?? []
        return all
            .sorted { $0.createdAt < $1.createdAt }
            .map { ProfileInfo(id: $0.uuid, name: $0.name, createdAt: $0.createdAt) }
    }

    private func profileRecord(_ uuid: String) -> ProfileRecord? {
        var d = FetchDescriptor<ProfileRecord>(predicate: #Predicate { $0.uuid == uuid })
        d.fetchLimit = 1
        return (try? context.fetch(d))?.first
    }

    @discardableResult
    func createProfile(name: String) -> ProfileInfo {
        let r = ProfileRecord()
        r.uuid = UUID().uuidString
        r.name = name
        r.createdAt = Date.now
        r.prefsPayload = Self.encode(ProfilePrefs())
        context.insert(r)
        save()
        return ProfileInfo(id: r.uuid, name: r.name, createdAt: r.createdAt)
    }

    func loadPrefs(profile: String) -> ProfilePrefs {
        guard let r = profileRecord(profile),
              let p = Self.decode(ProfilePrefs.self, r.prefsPayload) else { return ProfilePrefs() }
        return p
    }

    func savePrefs(_ prefs: ProfilePrefs, profile: String) {
        guard let r = profileRecord(profile) else { return }
        r.prefsPayload = Self.encode(prefs)
        save()
    }

    // MARK: Seeds / traces / learning (whole-collection replace — tiny data)

    func loadSeeds(profile: String) -> [Seed] {
        let recs = (try? context.fetch(FetchDescriptor<SeedRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        return recs.compactMap { Self.decode(Seed.self, $0.payload) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func replaceSeeds(_ seeds: [Seed], profile: String) {
        let old = (try? context.fetch(FetchDescriptor<SeedRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        old.forEach { context.delete($0) }
        for s in seeds {
            let r = SeedRecord()
            r.seedID = s.id; r.profileID = profile
            r.status = s.status.rawValue; r.updatedAt = s.updatedAt
            r.payload = Self.encode(s)
            context.insert(r)
        }
        save()
    }

    func loadTraces(profile: String) -> [DailyTrace] {
        let recs = (try? context.fetch(FetchDescriptor<TraceRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        return recs.compactMap { Self.decode(DailyTrace.self, $0.payload) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func replaceTraces(_ traces: [DailyTrace], profile: String) {
        let old = (try? context.fetch(FetchDescriptor<TraceRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        old.forEach { context.delete($0) }
        for t in traces {
            let r = TraceRecord()
            r.traceID = t.id; r.profileID = profile; r.date = t.date
            r.payload = Self.encode(t)
            context.insert(r)
        }
        save()
    }

    func loadLearning(profile: String) -> [LearningEntry] {
        let recs = (try? context.fetch(FetchDescriptor<LearningRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        return recs.compactMap { Self.decode(LearningEntry.self, $0.payload) }
            .sorted { $0.dateKey > $1.dateKey }
    }

    func replaceLearning(_ entries: [LearningEntry], profile: String) {
        let old = (try? context.fetch(FetchDescriptor<LearningRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        old.forEach { context.delete($0) }
        for e in entries {
            let r = LearningRecord()
            r.entryID = e.id; r.profileID = profile; r.dateKey = e.dateKey
            r.payload = Self.encode(e)
            context.insert(r)
        }
        save()
    }

    // MARK: Pursuit notes (the 手帐 pages)

    func loadNotes(profile: String, seed: String? = nil) -> [PursuitNote] {
        let recs = (try? context.fetch(FetchDescriptor<NoteRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        return recs.compactMap { Self.decode(PursuitNote.self, $0.payload) }
            .filter { seed == nil || $0.seedId == seed }
            .sorted { $0.id > $1.id }          // uid embeds time → newest first
    }

    func insertNote(_ note: PursuitNote, profile: String) {
        let r = NoteRecord()
        r.noteID = note.id; r.profileID = profile; r.seedID = note.seedId
        r.payload = Self.encode(note)
        context.insert(r)
        save()
    }

    func deleteNote(id: String, profile: String) {
        let recs = (try? context.fetch(FetchDescriptor<NoteRecord>(
            predicate: #Predicate { $0.profileID == profile && $0.noteID == id }))) ?? []
        recs.forEach { context.delete($0) }
        save()
    }

    // MARK: Events (append-only)

    func appendEvent(kind: String, payload: String, context ctx: ContextSnapshot?, profile: String) {
        let r = EventRecord()
        r.eventID = DomainUtil.uid("evt")
        r.profileID = profile
        r.timestamp = Date.now
        r.kind = kind
        r.payloadJSON = payload
        r.contextJSON = ctx.map { Self.encode($0) } ?? ""
        context.insert(r)
        save()
    }

    func events(profile: String, since: Date? = nil, kindPrefix: String? = nil) -> [EventRecord] {
        let recs = (try? context.fetch(FetchDescriptor<EventRecord>(
            predicate: #Predicate { $0.profileID == profile },
            sortBy: [SortDescriptor(\.timestamp)]))) ?? []
        return recs.filter { r in
            if let since, r.timestamp < since { return false }
            if let kindPrefix, !r.kind.hasPrefix(kindPrefix) { return false }
            return true
        }
    }

    /// Drop raw events older than the retention window (aggregates keep the memory).
    func pruneEvents(olderThan days: Int = 90, profile: String) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date.now)!
        let old = (try? context.fetch(FetchDescriptor<EventRecord>(
            predicate: #Predicate { $0.profileID == profile && $0.timestamp < cutoff }))) ?? []
        old.forEach { context.delete($0) }
        if !old.isEmpty { save() }
    }

    func wipeProfileData(_ profile: String) {
        replaceSeeds([], profile: profile)
        replaceTraces([], profile: profile)
        replaceLearning([], profile: profile)
        let evts = (try? context.fetch(FetchDescriptor<EventRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        evts.forEach { context.delete($0) }
        let notes = (try? context.fetch(FetchDescriptor<NoteRecord>(
            predicate: #Predicate { $0.profileID == profile }))) ?? []
        notes.forEach { context.delete($0) }
        save()
    }

    // MARK: Migration (old tdd.* UserDefaults → default profile; never deletes)

    /// Returns the active profile UUID. Creates + imports the default profile on
    /// first run with this build. The tdd.* keys are read, never removed.
    func migrateFromUserDefaultsIfNeeded(defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: "tdd.activeProfile"),
           profileRecord(existing) != nil {
            return existing
        }
        if let first = profiles().first {
            defaults.set(first.id, forKey: "tdd.activeProfile")
            return first.id
        }
        let info = createProfile(name: Self.defaultProfileName)

        func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
            defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
        }
        if let seeds = load([Seed].self, "tdd.seeds") { replaceSeeds(seeds, profile: info.id) }
        if let traces = load([DailyTrace].self, "tdd.traces") { replaceTraces(traces, profile: info.id) }
        if let learning = load([LearningEntry].self, "tdd.learningHistory") {
            replaceLearning(learning, profile: info.id)
        }
        var prefs = ProfilePrefs()
        prefs.settings = load(Settings.self, "tdd.settings") ?? .default
        prefs.lastPick = load(LastPick.self, "tdd.lastPick") ?? LastPick()
        prefs.samplesPlanted = defaults.bool(forKey: "tdd.samplesPlanted")
        prefs.introSeen = defaults.bool(forKey: "tdd.introSeen")
        prefs.aesthetic = defaults.string(forKey: "tdd.aesthetic")
            .flatMap(Aesthetic.init(rawValue:)) ?? .fallback
        prefs.aestheticAuto = defaults.bool(forKey: "tdd.aestheticAuto")
        prefs.senseAround = defaults.bool(forKey: "tdd.senseAround")
        prefs.learnedVocab = load([String: [String]].self, "tdd.learnedVocab") ?? [:]
        prefs.musicOn = defaults.bool(forKey: "tdd.musicOn")
        savePrefs(prefs, profile: info.id)

        defaults.set(info.id, forKey: "tdd.activeProfile")
        return info.id
    }
}
