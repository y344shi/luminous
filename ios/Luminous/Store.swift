//
//  Store.swift
//  Luminous
//
//  The single stateful glue: an @Observable store backed by UserDefaults
//  (the iOS analogue of the web app's localStorage). Ported from
//  lib/store.ts + lib/storage.ts. Every persisted write goes through `save…`.
//

import Foundation
import Observation

struct LastPick: Codable {
    var mood: Mood?
    var energy: Energy?
}

@Observable
final class AppStore {

    // MARK: Persistence keys (kept parallel to the web app's tdd.* keys)
    private enum Key {
        static let seeds = "tdd.seeds"
        static let traces = "tdd.traces"
        static let settings = "tdd.settings"
        static let samplesPlanted = "tdd.samplesPlanted"
        static let lastPick = "tdd.lastPick"
        static let introSeen = "tdd.introSeen"
        static let aesthetic = "tdd.aesthetic"
        static let aestheticAuto = "tdd.aestheticAuto"
        static let senseAround = "tdd.senseAround"
        static let learnedVocab = "tdd.learnedVocab"
        static let learningHistory = "tdd.learningHistory"
        static let musicOn = "tdd.musicOn"
        static let all = [seeds, traces, settings, samplesPlanted, lastPick, introSeen, aesthetic, aestheticAuto, senseAround, learnedVocab, learningHistory, musicOn]
    }

    // MARK: Persisted state
    var seeds: [Seed] = []
    var traces: [DailyTrace] = []
    var settings: Settings = .default
    var samplesPlanted = false
    var lastPick = LastPick()
    var introSeen = false

    /// The active visual skin (glass / ocean / paper). Persisted; drives
    /// `AestheticField` so switching it in Settings re-skins the app live.
    var aesthetic: Aesthetic = .fallback

    /// When true the skin follows the system appearance instead of `aesthetic`:
    /// Dark Mode → glass, Light Mode → paper. Persisted.
    var aestheticAuto: Bool = false

    /// Opt-in to sensing the surroundings (location → weather; mic/HR later).
    /// Motion is permission-free and always on; this gates the rest. Persisted.
    var senseAround: Bool = false

    /// Words the AI has already taught, per language — so long-term learning tasks
    /// build forward instead of repeating. Persisted.
    var learnedVocab: [String: [String]] = [:]

    /// The lasting record of learning moments (vocab picked, photos translated).
    /// Survives seed completion — a learning pursuit's history is worth keeping.
    /// Newest first. Persisted.
    var learningHistory: [LearningEntry] = []

    /// Play the skin's theme music on the dashboard. Off by default. Persisted.
    var musicOn: Bool = false

    // MARK: Transient state (not persisted)
    var opportunities: [Opportunity] = []
    var lastContext: ContextSnapshot?

    /// The soft, hourly mentality guess (never shown; one clamped scoring term).
    var mentality: MentalityEstimate?
    @ObservationIgnored var mentalityFetchedAt: Date?

    private let defaults: UserDefaults
    private let maxTraces = 500

    #if !os(watchOS)
    /// SwiftData backing store (nil → pure UserDefaults, as on the watch).
    @ObservationIgnored let persistence: Persistence?
    /// The active garden. Only the *default* (migrated) profile keeps the old
    /// tdd.* UserDefaults mirror fresh (dual-write rollback path); other
    /// profiles are SwiftData-native.
    private(set) var activeProfileID: String = ""
    @ObservationIgnored private var mirrorsToDefaults = true
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if !os(watchOS)
        self.persistence = Persistence.shared
        #endif
        hydrate()
    }

    var theme: ThemeName { settings.theme }
    var themeTokens: ThemeTokens { Theme.tokens(for: settings.theme) }

    // MARK: - Hydration

    private func hydrate() {
        #if !os(watchOS)
        if let p = persistence {
            activeProfileID = p.migrateFromUserDefaultsIfNeeded(defaults: defaults)
            mirrorsToDefaults = (p.profiles().first?.id == activeProfileID)
            hydrateActiveProfile(p)
            return
        }
        #endif
        hydrateFromDefaults()
    }

    /// The pre-SwiftData path — still the whole story on watchOS, and the
    /// fallback if the database can't open.
    private func hydrateFromDefaults() {
        seeds = load([Seed].self, Key.seeds) ?? []
        traces = load([DailyTrace].self, Key.traces) ?? []
        settings = load(Settings.self, Key.settings) ?? .default
        samplesPlanted = defaults.bool(forKey: Key.samplesPlanted)
        lastPick = load(LastPick.self, Key.lastPick) ?? LastPick()
        introSeen = defaults.bool(forKey: Key.introSeen)
        aesthetic = defaults.string(forKey: Key.aesthetic)
            .flatMap(Aesthetic.init(rawValue:)) ?? .fallback
        aestheticAuto = defaults.bool(forKey: Key.aestheticAuto)
        senseAround = defaults.bool(forKey: Key.senseAround)
        learnedVocab = load([String: [String]].self, Key.learnedVocab) ?? [:]
        learningHistory = load([LearningEntry].self, Key.learningHistory) ?? []
        musicOn = defaults.bool(forKey: Key.musicOn)

        // First run: plant a small mock garden so the app never feels empty.
        if seeds.isEmpty && traces.isEmpty {
            seeds = MockGarden.seed()
            persistSeeds()
            samplesPlanted = true
            defaults.set(true, forKey: Key.samplesPlanted)
        }
    }

    #if !os(watchOS)
    /// Load everything for the active profile from SwiftData.
    private func hydrateActiveProfile(_ p: Persistence) {
        p.pruneEvents(profile: activeProfileID)   // raw events: 90-day retention
        seeds = p.loadSeeds(profile: activeProfileID)
        traces = p.loadTraces(profile: activeProfileID)
        learningHistory = p.loadLearning(profile: activeProfileID)
        applyPrefs(p.loadPrefs(profile: activeProfileID))

        if seeds.isEmpty && traces.isEmpty {
            seeds = MockGarden.seed()
            persistSeeds()
            samplesPlanted = true
            persistPrefs()
        }
    }

    private func applyPrefs(_ prefs: ProfilePrefs) {
        settings = prefs.settings
        lastPick = prefs.lastPick
        samplesPlanted = prefs.samplesPlanted
        introSeen = prefs.introSeen
        aesthetic = prefs.aesthetic
        aestheticAuto = prefs.aestheticAuto
        senseAround = prefs.senseAround
        learnedVocab = prefs.learnedVocab
        musicOn = prefs.musicOn
    }

    private func currentPrefs() -> ProfilePrefs {
        var p = ProfilePrefs()
        p.settings = settings
        p.lastPick = lastPick
        p.samplesPlanted = samplesPlanted
        p.introSeen = introSeen
        p.aesthetic = aesthetic
        p.aestheticAuto = aestheticAuto
        p.senseAround = senseAround
        p.learnedVocab = learnedVocab
        p.musicOn = musicOn
        return p
    }
    #endif

    // MARK: - Persistence seams (dual-write: SwiftData + the old tdd.* mirror)

    private func persistSeeds() {
        #if os(watchOS)
        save(seeds, Key.seeds)
        #else
        if mirrorsToDefaults { save(seeds, Key.seeds) }
        persistence?.replaceSeeds(seeds, profile: activeProfileID)
        #endif
    }

    private func persistTraces() {
        #if os(watchOS)
        save(traces, Key.traces)
        #else
        if mirrorsToDefaults { save(traces, Key.traces) }
        persistence?.replaceTraces(traces, profile: activeProfileID)
        #endif
    }

    private func persistLearningHistory() {
        #if os(watchOS)
        save(learningHistory, Key.learningHistory)
        #else
        if mirrorsToDefaults { save(learningHistory, Key.learningHistory) }
        persistence?.replaceLearning(learningHistory, profile: activeProfileID)
        #endif
    }

    /// All scalar prefs (settings/lastPick/learnedVocab/skin/toggles) in one go.
    private func persistPrefs() {
        #if os(watchOS)
        save(settings, Key.settings)
        save(lastPick, Key.lastPick)
        save(learnedVocab, Key.learnedVocab)
        defaults.set(samplesPlanted, forKey: Key.samplesPlanted)
        defaults.set(introSeen, forKey: Key.introSeen)
        defaults.set(aesthetic.rawValue, forKey: Key.aesthetic)
        defaults.set(aestheticAuto, forKey: Key.aestheticAuto)
        defaults.set(senseAround, forKey: Key.senseAround)
        defaults.set(musicOn, forKey: Key.musicOn)
        #else
        if mirrorsToDefaults {
            save(settings, Key.settings)
            save(lastPick, Key.lastPick)
            save(learnedVocab, Key.learnedVocab)
            defaults.set(samplesPlanted, forKey: Key.samplesPlanted)
            defaults.set(introSeen, forKey: Key.introSeen)
            defaults.set(aesthetic.rawValue, forKey: Key.aesthetic)
            defaults.set(aestheticAuto, forKey: Key.aestheticAuto)
            defaults.set(senseAround, forKey: Key.senseAround)
            defaults.set(musicOn, forKey: Key.musicOn)
        }
        persistence?.savePrefs(currentPrefs(), profile: activeProfileID)
        #endif
    }

    // MARK: - Life-event log (no-op on the watch)

    /// Append one moment to the on-device event log, stamped with the coarse
    /// context of when it happened. The substrate for rhythm and recurrence.
    func logEvent(kind: String, payload: String = "") {
        #if !os(watchOS)
        persistence?.appendEvent(kind: kind, payload: payload,
                                 context: lastContext, profile: activeProfileID)
        #endif
    }

    // MARK: - iCloud sync (same-Apple-ID devices; iOS/macOS only)

    #if !os(watchOS)
    /// The user's wish to sync (device-local, takes effect at next launch —
    /// the SwiftData container is created once at startup).
    var cloudSyncOn: Bool = UserDefaults.standard.bool(forKey: "tdd.cloudSync")

    /// Whether THIS launch actually attached to CloudKit.
    var cloudSyncActive: Bool { persistence?.cloudActive ?? false }

    func setCloudSync(_ on: Bool) {
        cloudSyncOn = on
        defaults.set(on, forKey: "tdd.cloudSync")
    }

    /// Re-read everything for the active garden — called on foreground when
    /// cloud sync is live, so changes made on another device show up.
    func rehydrate() {
        guard let p = persistence else { return }
        hydrateActiveProfile(p)
    }
    #endif

    // MARK: - Gardens (multi-profile; iOS/macOS only)

    #if !os(watchOS)
    var gardens: [ProfileInfo] { persistence?.profiles() ?? [] }

    /// Per-seed recurrence stats from the outcome events (the rings, read back).
    /// Pursuits touched recently on their 手帐 page stay warm (engagedRecently).
    func seedHistory() -> [String: Recurrence.SeedStats] {
        guard let p = persistence else { return [:] }
        let outcomes = p.events(profile: activeProfileID, kindPrefix: "outcome.")
            .compactMap { r -> Outcome? in
                guard let kind = Outcome.Kind(rawValue: String(r.kind.dropFirst("outcome.".count)))
                else { return nil }
                let st = r.contextJSON.data(using: .utf8)
                    .flatMap { try? JSONDecoder().decode(ContextSnapshot.self, from: $0) }?
                    .semanticTime
                return Outcome(time: r.timestamp, seedId: r.payloadJSON,
                               kind: kind, semanticTime: st)
            }
        var stats = Recurrence.stats(outcomes)
        let weekAgo = Date().addingTimeInterval(-7 * 86_400)
        for e in p.events(profile: activeProfileID, since: weekAgo, kindPrefix: "pursuit.") {
            stats[e.payloadJSON, default: Recurrence.SeedStats()].engagedRecently = true
        }
        return stats
    }

    // MARK: - Pursuit notes (手帐; iOS/macOS only)

    func notes(for seedId: String) -> [PursuitNote] {
        persistence?.loadNotes(profile: activeProfileID, seed: seedId) ?? []
    }

    func addNote(_ text: String, to seedId: String, kind: PursuitNote.Kind = .note) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let p = persistence else { return }
        p.insertNote(PursuitNote(seedId: seedId, kind: kind, text: trimmed),
                     profile: activeProfileID)
        logEvent(kind: "pursuit.note", payload: seedId)
        noteBump += 1
    }

    func removeNote(_ id: String) {
        persistence?.deleteNote(id: id, profile: activeProfileID)
        noteBump += 1
    }

    /// Bumped on note changes so views re-read (notes aren't mirrored in memory).
    private(set) var noteBump = 0

    // MARK: - 今天的小机器 (the day-object; iOS/macOS only)

    /// Today's little machine — the stored one, or a fresh empty craft. Not held
    /// in memory (like notes); read on demand so it stays a light touch.
    func todayObject() -> DayObject {
        let key = DomainUtil.localDateKey()
        return persistence?.loadDayObject(dateKey: key, profile: activeProfileID)
            ?? DayObject(dateKey: key)
    }

    /// A completed wish grows ONE part on today's machine, shaped by how it felt.
    /// Re-completing the same wish replaces its part (never piles up). A machine
    /// with one part is already whole — no counts, no progress.
    func addPart(from seed: Seed, feel: PartFeel) {
        guard let p = persistence else { return }
        var obj = todayObject()
        obj.add(DayPart(seed: seed, feel: feel))
        p.saveDayObject(obj, profile: activeProfileID)
        logEvent(kind: "toy.part", payload: seed.id)
        toyBump += 1
    }

    /// Bumped when a part lands, so a surface watching the machine re-reads.
    private(set) var toyBump = 0

    /// Home/work grid cells learned from the last 90 days of coarse fixes.
    func learnedPlaceCells() -> (home: String?, work: String?) {
        guard let p = persistence else { return (nil, nil) }
        let obs = p.events(profile: activeProfileID, kindPrefix: "sense.cell")
            .map { Places.Observation(time: $0.timestamp, cell: $0.payloadJSON) }
        let home = Places.inferHome(obs)
        return (home, Places.inferWork(obs, home: home))
    }

    /// Today's sensed rhythm, phrased softly ("今天到现在：安坐 2 小时 · 走动 20 分钟").
    func todayDwellLine() -> String? {
        guard let p = persistence else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let samples = p.events(profile: activeProfileID, since: start,
                               kindPrefix: "sense.activity")
            .map { SenseSample(time: $0.timestamp, state: $0.payloadJSON) }
        return Rhythm.todayLine(samples, now: Date())
    }

    func createGarden(name: String) {
        guard let p = persistence else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = p.createProfile(name: trimmed.isEmpty ? "新的花园" : trimmed)
        switchGarden(info.id)
    }

    /// Move to another garden: everything re-hydrates from its records. The
    /// current garden's state is already persisted (write-through seams).
    func switchGarden(_ id: String) {
        guard let p = persistence, id != activeProfileID,
              p.profiles().contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        mirrorsToDefaults = (p.profiles().first?.id == id)
        defaults.set(id, forKey: "tdd.activeProfile")
        opportunities = []
        lastContext = nil
        hydrateActiveProfile(p)
    }
    #endif

    // MARK: - Seeds

    func addSeed(_ seed: Seed) {
        seeds.insert(seed, at: 0)
        persistSeeds()
        logEvent(kind: "seed.planted", payload: seed.title)
        if samplesPlanted {
            samplesPlanted = false
            persistPrefs()
        }
    }

    func updateSeed(_ id: String, _ mutate: (inout Seed) -> Void) {
        guard let idx = seeds.firstIndex(where: { $0.id == id }) else { return }
        mutate(&seeds[idx])
        seeds[idx].updatedAt = DomainUtil.nowIso()
        persistSeeds()
    }

    func setSeedStatus(_ id: String, _ status: SeedStatus) {
        updateSeed(id) { $0.status = status }
        logEvent(kind: "seed.status.\(status.rawValue)", payload: id)
    }

    func findSeed(_ id: String?) -> Seed? {
        guard let id = id else { return nil }
        return seeds.first { $0.id == id }
    }

    /// Recently-touched seeds for the Home preview (active/sleeping only).
    var recentSeeds: [Seed] {
        seeds.filter { $0.status == .active || $0.status == .sleeping }
    }

    // MARK: - Traces

    func addTrace(_ trace: DailyTrace) {
        traces.insert(trace, at: 0)
        if traces.count > maxTraces { traces = Array(traces.prefix(maxTraces)) }
        persistTraces()
        let outcome = trace.partial == true ? "partial" : "full"
        logEvent(kind: "trace.recorded.\(outcome)", payload: trace.seedId ?? "")
    }

    func updateTrace(_ id: String, text: String) {
        guard let idx = traces.firstIndex(where: { $0.id == id }) else { return }
        traces[idx].text = text
        persistTraces()
    }

    func removeTrace(_ id: String) {
        traces.removeAll { $0.id == id }
        persistTraces()
    }

    func tracesForToday() -> [DailyTrace] {
        let today = DomainUtil.localDateKey()
        return traces.filter { $0.date == today }
    }

    // MARK: - Opportunities (transient)

    func setOpportunities(_ opps: [Opportunity], _ ctx: ContextSnapshot) {
        opportunities = opps
        lastContext = ctx
    }

    func rememberPick(_ mood: Mood, _ energy: Energy) {
        lastPick = LastPick(mood: mood, energy: energy)
        persistPrefs()
    }

    // MARK: - Settings

    func setTheme(_ theme: ThemeName) {
        settings.theme = theme
        persistPrefs()
    }

    func updateSettings(_ mutate: (inout Settings) -> Void) {
        mutate(&settings)
        persistPrefs()
    }

    /// Switch the visual skin and persist it. Picking a skin by hand turns off
    /// auto (follow-system) mode. Re-skins the app immediately.
    func setAesthetic(_ a: Aesthetic) {
        aesthetic = a
        aestheticAuto = false
        persistPrefs()
    }

    /// Turn follow-system (Dark → glass / Light → paper) on or off. Persisted.
    func setAestheticAuto(_ on: Bool) {
        aestheticAuto = on
        persistPrefs()
    }

    /// Opt in / out of sensing the surroundings. Persisted.
    func setSenseAround(_ on: Bool) {
        senseAround = on
        persistPrefs()
    }

    func setMusicOn(_ on: Bool) {
        musicOn = on
        persistPrefs()
    }

    func learnedWords(_ language: String) -> [String] { learnedVocab[language] ?? [] }

    /// Remember words the AI just taught (deduped), so next time builds forward.
    func addLearnedWords(_ words: [String], language: String) {
        var list = learnedVocab[language] ?? []
        for w in words where !list.contains(w) { list.append(w) }
        learnedVocab[language] = Array(list.suffix(200))
        persistPrefs()
    }

    // MARK: - Learning history (kept across completion)

    /// Record a learning moment. Capped so it never grows without bound.
    func logLearning(_ entry: LearningEntry) {
        learningHistory.insert(entry, at: 0)
        if learningHistory.count > 300 { learningHistory = Array(learningHistory.prefix(300)) }
        persistLearningHistory()
    }

    /// History for one language (or all when nil), newest first.
    func learningEntries(language: String? = nil) -> [LearningEntry] {
        guard let language else { return learningHistory }
        return learningHistory.filter { $0.language == language }
    }

    /// Existing learning pursuits a new wish could merge into (any status), newest first.
    var learningSeeds: [Seed] {
        seeds.filter { LearningTopic.isLearning($0) }
    }

    /// Fold a new wish into an existing learning anchor: revive it, keep a light
    /// note of what was added, and log the merge. Returns the anchor's title.
    @discardableResult
    func mergeLearningSeed(newRaw: String, into anchorId: String) -> String? {
        guard let idx = seeds.firstIndex(where: { $0.id == anchorId }) else { return nil }
        let trimmed = newRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSeed(anchorId) { s in
            s.status = .active                       // resurface the pursuit
            if !trimmed.isEmpty, s.rawText != trimmed {
                let existing = s.description ?? ""
                s.description = existing.isEmpty ? trimmed : existing + "\n" + trimmed
            }
        }
        let lang = LearningTopic.language(ofTitle: seeds[idx].title) ?? "未知"
        logLearning(LearningEntry(kind: .vocab, language: lang, items: [],
                                  note: trimmed.isEmpty ? "又想起了这件事" : "又添了一句：\(trimmed)"))
        return seeds[idx].title
    }

    /// The skin to actually render. In auto mode it follows the system
    /// appearance; otherwise it's the user's chosen `aesthetic`.
    func effectiveAesthetic(dark: Bool) -> Aesthetic {
        aestheticAuto ? (dark ? .glass : .paper) : aesthetic
    }

    func dismissSamplesNote() {
        samplesPlanted = false
        persistPrefs()
    }

    func dismissIntro() {
        introSeen = true
        persistPrefs()
    }

    /// Reset the active garden back to the mock seedlings. On iOS this wipes the
    /// active profile's records too; the other gardens are untouched.
    func resetAll() {
        #if !os(watchOS)
        persistence?.wipeProfileData(activeProfileID)
        #endif
        if mirrorsDefaultsForReset { Key.all.forEach { defaults.removeObject(forKey: $0) } }
        traces = []
        settings = .default
        lastPick = LastPick()
        introSeen = false
        aesthetic = .fallback
        aestheticAuto = false
        senseAround = false
        learnedVocab = [:]
        learningHistory = []
        opportunities = []
        lastContext = nil
        seeds = MockGarden.seed()
        persistSeeds()
        persistTraces()
        persistLearningHistory()
        samplesPlanted = true
        persistPrefs()
    }

    private var mirrorsDefaultsForReset: Bool {
        #if os(watchOS)
        return true
        #else
        return mirrorsToDefaults
        #endif
    }

    // MARK: - JSON helpers

    private func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
