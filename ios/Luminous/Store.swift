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

    private let defaults: UserDefaults
    private let maxTraces = 500

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hydrate()
    }

    var theme: ThemeName { settings.theme }
    var themeTokens: ThemeTokens { Theme.tokens(for: settings.theme) }

    // MARK: - Hydration

    private func hydrate() {
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
            save(seeds, Key.seeds)
            samplesPlanted = true
            defaults.set(true, forKey: Key.samplesPlanted)
        }
    }

    // MARK: - Seeds

    func addSeed(_ seed: Seed) {
        seeds.insert(seed, at: 0)
        save(seeds, Key.seeds)
        if samplesPlanted {
            samplesPlanted = false
            defaults.set(false, forKey: Key.samplesPlanted)
        }
    }

    func updateSeed(_ id: String, _ mutate: (inout Seed) -> Void) {
        guard let idx = seeds.firstIndex(where: { $0.id == id }) else { return }
        mutate(&seeds[idx])
        seeds[idx].updatedAt = DomainUtil.nowIso()
        save(seeds, Key.seeds)
    }

    func setSeedStatus(_ id: String, _ status: SeedStatus) {
        updateSeed(id) { $0.status = status }
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
        save(traces, Key.traces)
    }

    func updateTrace(_ id: String, text: String) {
        guard let idx = traces.firstIndex(where: { $0.id == id }) else { return }
        traces[idx].text = text
        save(traces, Key.traces)
    }

    func removeTrace(_ id: String) {
        traces.removeAll { $0.id == id }
        save(traces, Key.traces)
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
        save(lastPick, Key.lastPick)
    }

    // MARK: - Settings

    func setTheme(_ theme: ThemeName) {
        settings.theme = theme
        save(settings, Key.settings)
    }

    func updateSettings(_ mutate: (inout Settings) -> Void) {
        mutate(&settings)
        save(settings, Key.settings)
    }

    /// Switch the visual skin and persist it. Picking a skin by hand turns off
    /// auto (follow-system) mode. Re-skins the app immediately.
    func setAesthetic(_ a: Aesthetic) {
        aesthetic = a
        aestheticAuto = false
        defaults.set(a.rawValue, forKey: Key.aesthetic)
        defaults.set(false, forKey: Key.aestheticAuto)
    }

    /// Turn follow-system (Dark → glass / Light → paper) on or off. Persisted.
    func setAestheticAuto(_ on: Bool) {
        aestheticAuto = on
        defaults.set(on, forKey: Key.aestheticAuto)
    }

    /// Opt in / out of sensing the surroundings. Persisted.
    func setSenseAround(_ on: Bool) {
        senseAround = on
        defaults.set(on, forKey: Key.senseAround)
    }

    func setMusicOn(_ on: Bool) {
        musicOn = on
        defaults.set(on, forKey: Key.musicOn)
    }

    func learnedWords(_ language: String) -> [String] { learnedVocab[language] ?? [] }

    /// Remember words the AI just taught (deduped), so next time builds forward.
    func addLearnedWords(_ words: [String], language: String) {
        var list = learnedVocab[language] ?? []
        for w in words where !list.contains(w) { list.append(w) }
        learnedVocab[language] = Array(list.suffix(200))
        save(learnedVocab, Key.learnedVocab)
    }

    // MARK: - Learning history (kept across completion)

    /// Record a learning moment. Capped so it never grows without bound.
    func logLearning(_ entry: LearningEntry) {
        learningHistory.insert(entry, at: 0)
        if learningHistory.count > 300 { learningHistory = Array(learningHistory.prefix(300)) }
        save(learningHistory, Key.learningHistory)
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
        defaults.set(false, forKey: Key.samplesPlanted)
    }

    func dismissIntro() {
        introSeen = true
        defaults.set(true, forKey: Key.introSeen)
    }

    func resetAll() {
        Key.all.forEach { defaults.removeObject(forKey: $0) }
        seeds = MockGarden.seed()
        save(seeds, Key.seeds)
        samplesPlanted = true
        defaults.set(true, forKey: Key.samplesPlanted)
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
