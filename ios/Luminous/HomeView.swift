//
//  HomeView.swift
//  Luminous
//
//  The "今天" tab — the centered, minimal Home: a glowing orb (the AI's read of
//  the moment) with the most-fitting wishes floating around it as boxless
//  illustration + title, and lesser wishes as small glass dots. Tap the orb to
//  step into 现在别消失; tap a wish to do it. Mirrors the web BubbleField home.
//

import SwiftUI
import MapKit

/// Navigation routes used across the Home stack.
enum Route: Hashable {
    case now
    case add
    case seedDetail(String)
}

/// A small row of category / duration / energy descriptors shared by cards.
struct SeedMetaRow: View {
    @Environment(\.theme) private var theme
    let seed: Seed

    var body: some View {
        FlowLayout(spacing: Spacing.xs) {
            ForEach(seed.categories, id: \.self) { cat in
                if let meta = Meta.category[cat] {
                    pill("\(meta.emoji) \(meta.label)")
                }
            }
            pill(Meta.durationLabel(seed.estimatedDurationMin))
            pill(Meta.energyLabel[seed.energyRequired] ?? "")
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(theme.textMuted)
            .background(theme.surfaceSoft)
            .clipShape(Capsule())
    }
}

// MARK: - Home

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(SensedSignals.self) private var sensed
    @State private var path = NavigationPath()

    /// A floating wish — a primary (ringed, illustrated) or a lesser dot.
    private struct Wish: Identifiable {
        let id: String
        let seed: Seed
        let opp: Opportunity?
        let primary: Bool
    }

    @State private var wishes: [Wish] = []
    @State private var picked: Wish?
    @State private var doneIds: Set<String> = []
    @State private var justTrace = ""
    @State private var breathe = false
    @State private var dragOffsets: [String: CGSize] = [:]
    @State private var caughtIds: Set<String> = []
    @State private var revealExtra = 0
    @State private var showTranslate = false
    @State private var sim = OrbitSim()
    @State private var aiMoments: [Suggestion] = []
    @State private var aiMomentsAt: Date?
    @State private var aiLoading = false
    @State private var aiVocab: [VocabItem] = []
    @State private var aiError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The active skin — the black hole is glass-only; ocean & paper get their own centers.
    private var skin: Aesthetic { store.effectiveAesthetic(dark: colorScheme == .dark) }

    private let orbR: CGFloat = 66

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var isLateNight: Bool { TimeOfDay.isLateNight(hour: hour) }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let size = geo.size
                let center = CGPoint(x: size.width / 2, y: size.height * 0.52)

                ZStack {
                    AestheticField(weather: sensed.weatherKind)
                        .ignoresSafeArea()
                        .simultaneousGesture(revealGesture)

                    bloom.position(center)
                    orb.position(center)

                    // Planetarium: wishes orbit the orb; tilt pulls them like a
                    // star; drag a planet (springs back); pull to reveal more.
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let places = placements()
                        // Step the real gravity sim this frame, then read positions
                        // back. The sim is a plain object (not observed), so this
                        // doesn't invalidate the view graph — no feedback loop.
                        let _ = stepSim(places, t: t)
                        ForEach(places, id: \.wish.id) { pl in
                            let p = simPosition(pl, center: center, size: size)
                            let drag = dragOffsets[pl.wish.id] ?? .zero
                            bubble(pl.wish)
                                .position(x: p.x + drag.width, y: p.y + drag.height)
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 8)
                                        .onChanged { v in dragOffsets[pl.wish.id] = v.translation }
                                        .onEnded { _ in
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                dragOffsets[pl.wish.id] = .zero
                                            }
                                        }
                                )
                        }
                    }

                    shootingStars(size: size)

                    topOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    bottomOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: size.width, height: size.height)
            }
            .hiddenNavBar()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .now: NowView(path: $path)
                case .add: AddSeedView(path: $path)
                case .seedDetail(let id): SeedDetailView(seedId: id)
                }
            }
            .sheet(item: $picked) { wish in
                #if os(iOS)
                wishSheet(wish)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.regularMaterial)
                #else
                wishSheet(wish).frame(minWidth: 380, minHeight: 440)
                #endif
            }
            .onChange(of: picked?.id) { _, _ in
                aiVocab = []; aiError = nil; aiLoading = false
            }
            .sheet(isPresented: $showTranslate) {
                TranslateView()
                #if os(iOS)
                    .presentationBackground(.regularMaterial)
                #else
                    .frame(minWidth: 420, minHeight: 560)
                #endif
            }
            .onAppear {
                rebuild()
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
            .onChange(of: store.seeds) { _, _ in rebuild() }
            .onChange(of: sensed.activity) { _, _ in rebuild() }
            .onChange(of: sensed.weatherKind) { _, _ in rebuild() }
        }
    }

    /// The day-line, with sensed bits appended (走着/在路上 · 晴/多云…) when present.
    private var dayLine: String {
        var bits: [String] = []
        switch sensed.activity {
        case .walking: bits.append("走着")
        case .transit: bits.append("在路上")
        default: break
        }
        switch sensed.weatherKind {
        case .clear: bits.append("晴")
        case .clouds: bits.append("多云")
        case .rain: bits.append("有雨")
        case .snow: bits.append("下雪")
        case .fog: bits.append("有雾")
        default: break
        }
        let base = DayGrade.line(hour: hour)
        return bits.isEmpty ? base : base + " · " + bits.joined(separator: " · ")
    }

    private var shown: [Wish] { wishes.filter { !doneIds.contains($0.id) } }

    // MARK: Orb

    private var bloom: some View {
        Circle()
            .fill(RadialGradient(
                colors: [theme.accent.opacity(0.28), .clear],
                center: .center, startRadius: 0, endRadius: orbR * 2.6))
            .frame(width: orbR * 5, height: orbR * 5)
            .blur(radius: 24)
            .allowsHitTesting(false)
    }

    private let hot = Color(red: 1.0, green: 0.62, blue: 0.26)

    /// The center: a black hole, rendered from the physics — event-horizon shadow,
    /// a hot accretion disk whose far side is gravitationally lensed up and over the
    /// top, a photon ring, and Doppler beaming (the approaching side brighter).
    @ViewBuilder private var orb: some View {
        Button { path.append(Route.now) } label: {
            Group {
                switch skin {
                case .glass: blackHoleVisual
                case .ocean: oceanVisual
                case .paper: paperVisual
                }
            }
            .frame(width: orbR * 2, height: orbR * 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.Home.primary)
    }

    /// Glass: a black hole (event-horizon shadow, lensed disk, photon ring, Doppler).
    private var blackHoleVisual: some View {
        let rs = orbR * 0.70
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [hot.opacity(0.30), .clear],
                                     center: .center, startRadius: rs, endRadius: orbR * 1.9))
                .blur(radius: 12)
                .scaleEffect(breathe ? 1.05 : 0.98)
            lensedArc(rs).blur(radius: 2)
            accretionDisk(rs).blur(radius: 3)
            Circle().fill(.black).frame(width: rs * 2, height: rs * 2)
            accretionDisk(rs)
                .mask(Rectangle().frame(width: orbR * 2, height: rs).offset(y: rs * 0.5))
                .blur(radius: 2)
            Circle()
                .stroke(AngularGradient(colors: [hot, .white, hot, hot.opacity(0.5), hot],
                                        center: .center, angle: .degrees(-90)), lineWidth: 2)
                .frame(width: rs * 2 + 3, height: rs * 2 + 3)
                .blur(radius: 0.4)
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.6), .clear],
                                     center: .center, startRadius: 0, endRadius: rs))
                .frame(width: rs * 1.5, height: rs * 0.55)
                .offset(x: -rs * 0.85)
                .blendMode(.plusLighter)
        }
    }

    /// Ocean: a luminous moon over the water — soft glow + scene glyph.
    private var oceanVisual: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.9), theme.accentSoft.opacity(0.5), .clear],
                                     center: .center, startRadius: 0, endRadius: orbR * 1.5))
                .blur(radius: 8)
                .scaleEffect(breathe ? 1.05 : 0.98)
            Circle().fill(.ultraThinMaterial).frame(width: orbR * 2 - 6, height: orbR * 2 - 6)
            Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1).frame(width: orbR * 2 - 6, height: orbR * 2 - 6)
            VStack(spacing: 4) {
                Image(systemName: sceneIcon).font(.system(size: 30, weight: .light))
                Text(sceneLabel).font(.system(size: 11)).tracking(2)
            }
            .foregroundStyle(theme.textPrimary)
        }
    }

    /// Paper: a hand-drawn ink circle — a little sketched sun.
    private var paperVisual: some View {
        ZStack {
            Circle().fill(theme.surface.opacity(0.35)).frame(width: orbR * 2 - 8, height: orbR * 2 - 8)
            Circle().strokeBorder(theme.textSecondary.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [0.5, 3]))
                .frame(width: orbR * 2 - 8, height: orbR * 2 - 8)
            Circle().strokeBorder(theme.textSecondary.opacity(0.35), lineWidth: 1)
                .frame(width: orbR * 2, height: orbR * 2)
            VStack(spacing: 4) {
                Image(systemName: sceneIcon).font(.system(size: 28, weight: .light))
                    .foregroundStyle(theme.textSecondary)
                Text(sceneLabel).font(.system(size: 11)).foregroundStyle(theme.textMuted)
            }
        }
    }

    /// The edge-on accretion disk: a wide, thin hot ellipse; its left/right wings
    /// extend beyond the shadow.
    private func accretionDisk(_ rs: CGFloat) -> some View {
        Ellipse()
            .fill(LinearGradient(
                colors: [hot.opacity(0.15), .white, hot, hot.opacity(0.2)],
                startPoint: .leading, endPoint: .trailing))
            .frame(width: rs * 2.9, height: rs * 0.62)
    }

    /// The lensed far side, bent up and over the top of the hole — a bright arc.
    private func lensedArc(_ rs: CGFloat) -> some View {
        Circle()
            .trim(from: 0.56, to: 0.94)
            .stroke(LinearGradient(colors: [hot.opacity(0.4), .white, hot.opacity(0.4)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: rs * 0.34, lineCap: .round))
            .frame(width: rs * 2.1, height: rs * 2.1)
    }

    // MARK: Wishes

    @ViewBuilder private func bubble(_ wish: Wish) -> some View {
        let symbol = glyph(for: wish.seed)
        if wish.primary {
            Button { picked = wish } label: {
                VStack(spacing: 6) {
                    planet(symbol, diameter: 54, iconSize: 22, glow: true)
                    Text(wish.seed.title)
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 96)
                    if let place = matchedPlace(for: wish.seed) {
                        Text("\(place.emoji)\(place.distanceLabel)")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            Button { picked = wish } label: {
                planet(symbol, diameter: 38, iconSize: 15, glow: false).opacity(0.85)
            }
            .buttonStyle(.plain)
        }
    }

    /// A little celestial body — a softly-lit disc with a line-art glyph.
    private func planet(_ symbol: String, diameter: CGFloat, iconSize: CGFloat, glow: Bool) -> some View {
        ZStack {
            Circle().fill(RadialGradient(
                colors: [theme.surface.opacity(0.95), theme.accentSoft.opacity(0.55), theme.surfaceSoft.opacity(0.3)],
                center: UnitPoint(x: 0.34, y: 0.30), startRadius: 0, endRadius: diameter * 0.62))
            Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .light))
                .foregroundStyle(theme.textPrimary)
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: glow ? theme.accent.opacity(0.4) : .clear, radius: glow ? 8 : 0)
    }

    /// A cohesive line-art glyph per wish, varied within a category by seed id so
    /// two similar wishes don't repeat the same icon.
    private func glyph(for seed: Seed) -> String {
        let cat = seed.categories.first ?? .recovery
        let pool = Self.glyphPool[cat] ?? ["sparkle"]
        return pool[abs(seed.id.hashValue) % pool.count]
    }

    private static let glyphPool: [SeedCategory: [String]] = [
        .body:        ["leaf", "cup.and.saucer", "drop", "wind"],
        .creation:    ["pencil.and.outline", "paintbrush.pointed", "scribble.variable", "music.note"],
        .connection:  ["heart", "bubble.left.and.bubble.right", "hand.wave", "envelope"],
        .exploration: ["figure.walk", "map", "binoculars", "mountain.2"],
        .recovery:    ["moon.stars", "bed.double", "humidity", "sparkles"],
        .learning:    ["book", "character.book.closed", "graduationcap", "lightbulb"],
        .aesthetic:   ["camera", "leaf.circle", "sparkle", "photo.artframe"],
    ]

    /// Primaries settle in a ring round the orb; lesser wishes rest in stable
    /// pseudo-random spots across the field (derived from the seed id, not random
    /// each render). Everything is clamped to stay on screen.
    // MARK: Planetarium orbits

    private struct Placement: Identifiable {
        let wish: Wish
        let ring: Int
        let idx: Int
        let count: Int
        var id: String { wish.id }
    }

    /// The wishes currently displayed: the top 3 (inner orbit) plus however many
    /// lower-ranked wishes the user has pulled into view (outer orbits).
    private var displayed: [Wish] {
        let s = shown
        let primaries = s.filter { $0.primary }
        let ambient = s.filter { !$0.primary }
        return primaries + Array(ambient.prefix(revealExtra))
    }

    /// Group displayed wishes into concentric orbits: primaries on the inner ring,
    /// revealed wishes filling progressively larger outer rings.
    private func placements() -> [Placement] {
        let disp = displayed
        let primaries = disp.filter { $0.primary }
        let ambient = disp.filter { !$0.primary }
        var out: [Placement] = []
        for (i, w) in primaries.enumerated() {
            out.append(Placement(wish: w, ring: 0, idx: i, count: max(primaries.count, 1)))
        }
        var ring = 1, cap = 4, rem = ambient
        while !rem.isEmpty {
            let take = Array(rem.prefix(cap))
            for (i, w) in take.enumerated() {
                out.append(Placement(wish: w, ring: ring, idx: i, count: take.count))
            }
            rem = Array(rem.dropFirst(cap)); ring += 1; cap += 1
        }
        return out
    }

    /// Step the gravity sim one frame: make sure a body exists per placement, then
    /// integrate to `t` under the central pull + the device-tilt field. The tilt
    /// removes the upright baseline (g.height ≈ −1 when held vertically) so only a
    /// real lean perturbs the orbits.
    private func stepSim(_ places: [Placement], t: TimeInterval) {
        sim.sync(places.map { ($0.wish.id, $0.ring, $0.idx, $0.count) })
        let g = sensed.gravity
        let tilt = CGSize(width: g.width, height: g.height + 1.0)
        sim.step(to: t, tilt: tilt, paused: reduceMotion)
    }

    /// Read a body's simulated screen position (clamped on-screen). Falls back to
    /// the orb centre if the body isn't seeded yet.
    private func simPosition(_ pl: Placement, center: CGPoint, size: CGSize) -> CGPoint {
        let p = sim.screenPos(pl.wish.id, center: center) ?? center
        return CGPoint(x: clamp(p.x, 44, size.width - 44),
                       y: clamp(p.y, 100, size.height - 120))
    }

    /// Pull down on the field to reveal more (lower-ranked) wishes; pull up to fold.
    private var revealGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { v in
                let ambientCount = shown.filter { !$0.primary }.count
                if v.translation.height > 50 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        revealExtra = min(revealExtra + 3, ambientCount)
                    }
                } else if v.translation.height < -50 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        revealExtra = max(revealExtra - 3, 0)
                    }
                }
            }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), max(lo, hi))
    }

    // MARK: Overlays

    private var topOverlay: some View {
        VStack(spacing: 6) {
            Text(Copy.appTitle)
                .font(.system(size: 13))
                .tracking(6)
                .foregroundStyle(theme.textMuted)
            Text(dayLine)
                .font(.system(size: 12))
                .italic()
                .foregroundStyle(theme.textSecondary)
            if isLateNight {
                Text(Copy.LateNight.title)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textMuted)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 8)
    }

    /// Context-born suggestions, shown as shooting stars. The scout's finds
    /// (an existing wish × a fitting place right here) lead; generic moment
    /// suggestions fill the rest. Late night only ever offers calm stop-loss.
    private var suggestions: [Suggestion] {
        let scouted = OpportunityScout.scout(
            seeds: store.seeds,
            spots: sensed.nearby.compactMap { p in
                p.kind.map { OpportunityScout.Spot(name: p.name, kind: $0, distanceM: p.distanceM) }
            },
            hour: hour,
            isLateNight: isLateNight
        )
        let base = Suggester.suggest(
            hour: hour,
            isLateNight: isLateNight,
            weather: sensed.weatherKind,
            activity: sensed.activity,
            nearbyCafe: sensed.nearbyCafe,
            nearbyOuting: sensed.nearbyOuting
        )
        // scout finds > model's moments > the static floor
        let ai = isLateNight ? [] : aiMoments
        return Array((scouted + ai + base).filter { !caughtIds.contains($0.id) }.prefix(3))
    }

    /// Ask the model for fresh moment suggestions at most every 30 minutes.
    /// Late night never asks — the stop-loss pool is code-owned.
    private func refreshAIMoments() {
        guard !isLateNight, AIHelper.isAvailable else { return }
        if let at = aiMomentsAt, Date().timeIntervalSince(at) < 1800 { return }
        aiMomentsAt = Date()
        let line = aiContext()
        Task {
            let fresh = await SuggestAI.moments(contextLine: line)
            await MainActor.run { if !fresh.isEmpty { aiMoments = fresh } }
        }
    }

    /// Suggestions streak across the sky as shooting stars; tap one to catch it.
    @ViewBuilder private func shootingStars(size: CGSize) -> some View {
        let items = suggestions
        if !items.isEmpty {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                ForEach(Array(items.enumerated()), id: \.element.id) { i, s in
                    let prog = reduceMotion
                        ? 0.4
                        : (t / 16.0 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1)
                    if prog < 0.85 {
                        let f = CGFloat(prog / 0.85)
                        let start = CGPoint(x: size.width * 1.08, y: size.height * (0.10 + Double(i) * 0.06))
                        let end = CGPoint(x: size.width * 0.10, y: size.height * (0.26 + Double(i) * 0.07))
                        let travel = atan2(end.y - start.y, end.x - start.x)  // velocity direction
                        shootingStar(s, travel: travel)
                            .position(x: start.x + (end.x - start.x) * f,
                                      y: start.y + (end.y - start.y) * f)
                            .opacity(Double(min(1, min(f * 5, (1 - f) * 5))))
                    }
                }
            }
        }
    }

    /// A meteor: the head leads, the train trails exactly anti-parallel to the
    /// velocity (`travel`), fading from bright at the head to nothing behind.
    private func shootingStar(_ s: Suggestion, travel: Double) -> some View {
        let L: CGFloat = 64
        return Button { catchSuggestion(s) } label: {
            ZStack {
                // train — bright (trailing end) at the head, fading backward
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.85)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: L, height: 2.5)
                    .rotationEffect(.radians(travel))
                    .offset(x: -CGFloat(cos(travel)) * L / 2, y: -CGFloat(sin(travel)) * L / 2)
                    .blur(radius: 0.5)
                // head — kept upright + readable
                Circle().fill(.white.opacity(0.55)).frame(width: 30, height: 30)
                    .blur(radius: 7).scaleEffect(breathe ? 1.2 : 0.9)
                Text(s.emoji).font(.system(size: 17))
                Text(s.title).font(.system(size: 9))
                    .foregroundStyle(theme.textSecondary).lineLimit(1).fixedSize()
                    .offset(y: 27)
                if let place = s.place {
                    Text(place).font(.system(size: 8))
                        .foregroundStyle(theme.textMuted).lineLimit(1).fixedSize()
                        .offset(y: 38)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// The nearest place that suits this wish's nature (learn → library/cafe …).
    private func matchedPlace(for seed: Seed) -> NearbyPlace? {
        guard nearbyAppropriate else { return nil }
        var kinds = Set<PlaceKind>()
        for c in seed.categories { if let a = Scoring.placeAffinity[c] { kinds.formUnion(a) } }
        return sensed.nearby.first { p in p.kind.map { kinds.contains($0) } ?? false }
    }

    // MARK: AI help — let the on-device model do the task it can

    /// If a wish is a "learn <language>" task, which language. Single source of
    /// truth in `LearningTopic` so Store, the add flow and this card all agree.
    private func helpLanguage(for seed: Seed) -> String? {
        LearningTopic.language(ofTitle: seed.title)
    }

    private func kindName(_ k: PlaceKind) -> String {
        switch k {
        case .cafe: return "咖啡馆"; case .library: return "图书馆"; case .park: return "公园"
        case .market: return "市场"; case .store: return "商店"; case .restaurant: return "餐馆"
        case .gym: return "健身房"; case .museum: return "博物馆"
        }
    }

    /// The sensed moment, as a short line the model can personalize from.
    private func aiContext() -> String {
        var bits = [DayGrade.line(hour: hour)]
        switch sensed.weatherKind {
        case .clear: bits.append("晴"); case .clouds: bits.append("多云")
        case .rain: bits.append("有雨"); case .snow: bits.append("下雪"); case .fog: bits.append("有雾")
        default: break
        }
        let kinds = nearbyAppropriate ? sensed.nearbyKinds : []
        if !kinds.isEmpty { bits.append("附近有" + kinds.map(kindName).joined(separator: "、")) }
        return bits.joined(separator: " · ")
    }

    @ViewBuilder private func aiSection(for wish: Wish) -> some View {
        if let lang = helpLanguage(for: wish.seed) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                if !aiVocab.isEmpty {
                    ForEach(aiVocab) { v in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(v.word).font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                Text(v.meaning).font(.system(size: 13))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Text(v.example).font(.system(size: 12))
                                .foregroundStyle(theme.textMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.sm)
                        .background(theme.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                } else if AIHelper.isAvailable {
                    Button { runAI(language: lang) } label: {
                        HStack(spacing: 6) {
                            if aiLoading { ProgressView().controlSize(.small) }
                            else { Image(systemName: "sparkles") }
                            Text(aiLoading ? "正在挑词…" : "让 AI 帮我挑三个\(lang)词")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.accentSoft)
                        .foregroundStyle(theme.accentText)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(aiLoading)
                } else {
                    Text(AIHelper.unavailableReason)
                        .font(.system(size: 12)).foregroundStyle(theme.textMuted)
                }
                if let aiError {
                    Text(aiError).font(.system(size: 12)).foregroundStyle(.red.opacity(0.85))
                }

                // Snap a real-world sign / menu in this language and read it both ways.
                Button { showTranslate = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.viewfinder")
                        Text("拍张\(lang)的照片，翻成中英文")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(theme.textPrimary)
                    .padding(.vertical, 10).padding(.horizontal, Spacing.md)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                learningHistoryStrip(lang)
            }
        }
    }

    /// A quiet record that this pursuit has a past — kept even after it's "done".
    @ViewBuilder private func learningHistoryStrip(_ lang: String) -> some View {
        let entries = store.learningEntries(language: lang)
        if !entries.isEmpty {
            let learnedCount = store.learnedWords(lang).count
            VStack(alignment: .leading, spacing: 4) {
                Text(learnedCount > 0
                     ? "一路上：学过 \(learnedCount) 个词 · \(entries.count) 次记录"
                     : "一路上：\(entries.count) 次记录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.textMuted)
                ForEach(entries.prefix(3)) { e in
                    Text(historyLine(e))
                        .font(.system(size: 12)).lineLimit(1)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
    }

    private func historyLine(_ e: LearningEntry) -> String {
        let when = DomainUtil.friendlyDate(e.dateKey)
        let what: String
        switch e.kind {
        case .vocab:     what = e.items.isEmpty ? (e.note ?? "挑了新词") : e.items.prefix(3).joined(separator: "、")
        case .translate: what = "📷 " + (e.items.first ?? e.note ?? "翻译了一张照片")
        }
        return "· \(when) \(what)"
    }

    private func runAI(language: String) {
        aiError = nil; aiLoading = true
        let learned = store.learnedWords(language)
        let context = aiContext()
        Task {
            do {
                let words = try await AIHelper.vocab(language: language, learned: learned, context: context)
                await MainActor.run {
                    aiVocab = words; aiLoading = false
                    store.logLearning(LearningEntry(kind: .vocab, language: language,
                                                    items: words.map(\.word)))
                }
            } catch {
                await MainActor.run { aiError = "没能挑出来，待会儿再试"; aiLoading = false }
            }
        }
    }

    private func catchSuggestion(_ s: Suggestion) {
        Feedback.completion(.partial)   // a soft "caught" tap
        // A scouted star carries an existing wish to a nearby place — open it.
        if let seedId = s.seedId, let seed = store.findSeed(seedId) {
            picked = wishes.first { $0.seed.id == seedId }
                ?? Wish(id: "scout_\(seedId)", seed: seed, opp: nil, primary: false)
            return
        }
        store.addSeed(s.toSeed())
        caughtIds.insert(s.id)
        withAnimation { justTrace = "接住了一个新念头：\(s.title)" }
        rebuild()
    }

    private var bottomOverlay: some View {
        VStack(spacing: 12) {
            if !justTrace.isEmpty {
                Text(justTrace)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: 270)
                    .transition(.opacity)
            }
            HStack(spacing: 18) {
                Button { showTranslate = true } label: {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("拍照翻译")

                Button { path.append(Route.add) } label: {
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Copy.Home.addSeed)
            }
        }
        .padding(.bottom, 14)
    }

    /// Only surface "out and about" places when it actually fits the moment —
    /// never late at night (the stop-loss gate), and only during daytime/early
    /// evening. Going out isn't a kindness at 1 AM.
    private var nearbyAppropriate: Bool {
        !isLateNight && (8...20).contains(hour)
    }

    // MARK: Tap-a-wish sheet

    private func wishSheet(_ wish: Wish) -> some View {
        let seed = wish.seed
        let emoji = Meta.category[seed.categories.first ?? .recovery]?.emoji ?? "🫧"
        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(emoji).font(.system(size: 54))
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.sm)
                Text(seed.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Text(wish.opp?.suggestedAction ?? seed.minimumAction)
                    .font(.system(size: 15)).lineSpacing(4)
                    .foregroundStyle(theme.textSecondary)
                if let reason = wish.opp?.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 13)).lineSpacing(4)
                        .foregroundStyle(theme.textSecondary)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let place = matchedPlace(for: seed) {
                    Button { place.mapItem.openInMaps() } label: {
                        HStack(spacing: 6) {
                            Text(place.emoji)
                            Text("可以在附近的\(place.name)做 · \(place.distanceLabel)")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.accentText)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }

                aiSection(for: wish)
                ExecutorSection(seed: seed)

                VStack(spacing: Spacing.sm) {
                    SoftButton(title: Copy.Completion.done) {
                        if let lang = helpLanguage(for: seed), !aiVocab.isEmpty {
                            store.addLearnedWords(aiVocab.map(\.word), language: lang)
                        }
                        complete(wish, .completed)
                    }
                    SoftButton(title: Copy.Completion.partial, variant: .soft) { complete(wish, .partial) }
                    SoftButton(title: Copy.Now.later, variant: .ghost) { picked = nil }
                }
                .padding(.top, Spacing.xs)
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: Build + complete

    private func rebuild() {
        let ctx = ContextBuilder.build(ContextInput(
            mood: store.lastPick.mood ?? .okay,
            energy: store.lastPick.energy ?? .medium,
            locationHint: sensed.locationHint,
            isOutdoorWeatherGood: sensed.isOutdoorWeatherGood,
            isMobile: true,
            activity: sensed.activity,
            weatherKind: sensed.weatherKind,
            nearbyKinds: nearbyAppropriate ? sensed.nearbyKinds : []
        ))
        let opps = Scoring.recommend(store.seeds, ctx, history: store.seedHistory(),
                                     mentality: store.mentality, limit: 3)
        store.setOpportunities(opps, ctx)   // keeps lastContext fresh for the event log
        store.refreshMentalityIfStale()     // hourly, on-device, fire-and-forget
        refreshAIMoments()                  // half-hourly, on-device, fire-and-forget
        let primaryIds = Set(opps.map { $0.seedId })
        var next: [Wish] = []
        for o in opps {
            if let seed = store.findSeed(o.seedId) {
                next.append(Wish(id: o.id, seed: seed, opp: o, primary: true))
            }
        }
        let ambient = store.seeds
            .filter { ($0.status == .active || $0.status == .sleeping) && !primaryIds.contains($0.id) }
            .prefix(8)
        for seed in ambient {
            next.append(Wish(id: "amb_\(seed.id)", seed: seed, opp: nil, primary: false))
        }
        wishes = next
    }

    private func complete(_ wish: Wish, _ kind: CompletionKind) {
        Feedback.completion(kind)
        let seed = wish.seed
        store.logEvent(kind: "outcome.\(String(describing: kind))", payload: seed.id)
        let trace = TraceGenerator.buildTrace(seed, kind, opportunityId: wish.opp?.id)
        store.addTrace(trace)
        if kind == .completed { store.setSeedStatus(seed.id, .sleeping) }
        withAnimation { justTrace = trace.text }
        doneIds.insert(wish.id)
        picked = nil
    }

    // MARK: Scene glyph (orb)

    private var sceneIcon: String {
        switch DayGrade.phase(hour: hour) {
        case .dawn:      return "sunrise"
        case .morning:   return "sun.max"
        case .noon:      return "sun.max.fill"
        case .afternoon: return "sun.min"
        case .dusk:      return "sunset"
        case .night:     return "moon.stars"
        }
    }

    private var sceneLabel: String {
        switch DayGrade.phase(hour: hour) {
        case .dawn:      return "清晨"
        case .morning:   return "上午"
        case .noon:      return "正午"
        case .afternoon: return "午后"
        case .dusk:      return "黄昏"
        case .night:     return "夜里"
        }
    }
}
