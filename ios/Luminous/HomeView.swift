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
    /// The just-completed wish's seed, awaiting its gentle 感觉怎么样? rating.
    @State private var ratingSeed: Seed?
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
    @State private var birth: StarBirth?
    @State private var canvasSize: CGSize = .zero
    /// Moons: seedId → parent seedId (transient this session; not persisted yet).
    @State private var moonOf: [String: String] = [:]
    /// A related fly-by awaiting the user's choice (moon of X, or separate).
    @State private var moonChoice: MoonChoice?
    @State private var aiLoading = false
    @State private var aiVocab: [VocabItem] = []
    @State private var aiError: String?
    @State private var aiTheme: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    /// The active skin — the black hole is glass-only; ocean & paper get their own centers.
    private var skin: Aesthetic { store.effectiveAesthetic(dark: colorScheme == .dark) }

    private let orbR: CGFloat = 66

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var isLateNight: Bool { TimeOfDay.isLateNight(hour: hour) }

    /// Late night AND we can tell you're out (or sensing is off, so we offer to
    /// turn it on). At home late → the gentle water/sleep stop-loss is enough.
    private var showLateNightCare: Bool {
        guard isLateNight else { return false }
        if !store.senseAround { return true }
        return sensed.locationHint != .home
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let size = geo.size
                let center = CGPoint(x: size.width / 2, y: size.height * 0.52)

                ZStack {
                    AestheticField(weather: sensed.weatherKind)
                        .ignoresSafeArea()
                        .simultaneousGesture(revealGesture)

                    if skin == .glass {
                    // 记忆星座 — every trace is a permanent star in YOUR sky.
                    ConstellationSkyView(traces: store.traces, size: size,
                                         bornBeingHidden: birth?.traceId)
                        .ignoresSafeArea()

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
                        // Moons: small satellites orbiting their parent planet.
                        ForEach(activeMoonSeeds, id: \.id) { seed in
                            let mp = moonPosition(seed.id, center: center, size: size)
                            Button {
                                picked = wishes.first { $0.seed.id == seed.id }
                                    ?? Wish(id: "moon_\(seed.id)", seed: seed, opp: nil, primary: false)
                            } label: {
                                planet(glyph(for: seed), diameter: 26, iconSize: 11, glow: false)
                                    .opacity(0.9)
                            }
                            .buttonStyle(.plain)
                            .position(mp)
                        }
                    }

                    shootingStars(size: size)

                    // The birth ceremony: infall → flare → rise → bloom.
                    if let birth {
                        BirthOverlay(birth: birth, center: center) {
                            self.birth = nil
                        }
                    }

                    // Late night and out → the app's oldest promise: help you get
                    // home safely, as guiding stars orbiting the glass.
                    if showLateNightCare {
                        LateNightCareOrbit(center: center, size: size)
                            .transition(.opacity)
                    }
                    } else if skin == .ocean {
                        // A literal liquid ocean — wishes float, bigger = more
                        // relevant, and the water sloshes with the gyro.
                        OceanField(
                            items: shown.map {
                                OceanField.Item(id: $0.seed.id, seed: $0.seed,
                                                importance: importance(of: $0))
                            },
                            size: size, tilt: sensed.gravity,
                            onTap: { id in picked = wishes.first { $0.seed.id == id } },
                            glyph: glyph(for:))
                    } else {
                        // Paper: a calm recommendation-ordered list.
                        wishListField
                    }

                    // Late night and out, on ocean/paper → the same get-home care
                    // as a compact top strip (the orbit is a glass-only affordance).
                    if showLateNightCare && skin != .glass {
                        LateNightCareStrip()
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, 84)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                    }

                    topOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    bottomOverlay
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(width: size.width, height: size.height)
                .onAppear { canvasSize = size }
                .onChange(of: size) { _, s in canvasSize = s }
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
            // A related fly-by: let it become a moon of X, or a separate star.
            .confirmationDialog(
                moonChoice.map { "「\(store.findSeed($0.seedId)?.title ?? "")」" } ?? "",
                isPresented: Binding(get: { moonChoice != nil },
                                     set: { if !$0 { moonChoice = nil } }),
                titleVisibility: .visible
            ) {
                if let c = moonChoice {
                    Button("成为「\(c.parentTitle)」的卫星") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            moonOf[c.seedId] = c.parentId
                        }
                        caughtIds.insert(c.sugId)
                        moonChoice = nil
                    }
                    Button("做一颗独立的星") {
                        store.setSeedStatus(c.seedId, .active)   // its own planet
                        caughtIds.insert(c.sugId)
                        moonChoice = nil
                        rebuild()
                    }
                    Button("再看看", role: .cancel) { moonChoice = nil }
                }
            } message: {
                Text("它和你正在做的事有关。想让它跟着那颗星转，还是自己成为一颗星？")
            }
            // After a wish is done: one soft question that grows today's machine.
            .sheet(item: $ratingSeed) { seed in
                FeltRatingView { feel in
                    store.addPart(from: seed, feel: feel)
                    ratingSeed = nil
                    withAnimation { justTrace = "今天的小机器，多了一个零件" }
                }
                #if os(iOS)
                .presentationDetents([.height(360)])
                .presentationBackground(.regularMaterial)
                #else
                .frame(minWidth: 360, minHeight: 340)
                #endif
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

    // MARK: Non-glass home — a calm list (paper's home; ocean's until W5b)

    private var wishListField: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // The skin's orb, compact, still the tap into 现在别消失.
                orb.scaleEffect(0.66).frame(height: 96).padding(.top, 86)
                ForEach(shown, id: \.id) { wish in
                    Button { picked = wish } label: { wishRow(wish) }
                        .buttonStyle(.plain)
                }
                if shown.isEmpty {
                    Text("今天还很空。捞一个小小的念头吧。")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, 150)
        }
    }

    private func wishRow(_ wish: Wish) -> some View {
        HStack(spacing: Spacing.md) {
            planet(glyph(for: wish.seed), diameter: 40, iconSize: 16, glow: wish.primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(wish.seed.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.textPrimary).lineLimit(1)
                Text(wish.opp?.suggestedAction ?? wish.seed.minimumAction)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            if let place = matchedPlace(for: wish.seed) {
                Text("\(place.emoji)\(place.distanceLabel)")
                    .font(.system(size: 11)).foregroundStyle(theme.textMuted)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.surface.opacity(wish.primary ? 0.96 : 0.82))
                // A ruled notebook margin down the left edge.
                Rectangle().fill(theme.accentSoft)
                    .frame(width: 3).padding(.vertical, 9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(theme.border.opacity(0.7), lineWidth: 1))
        .shadow(color: theme.textPrimary.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: Wishes

    @ViewBuilder private func bubble(_ wish: Wish) -> some View {
        let symbol = glyph(for: wish.seed)
        // Size by importance: a more relevant, heavier wish is a bigger planet.
        let d = CGFloat(PlanetPhysics.diameter(importance: importance(of: wish),
                                               primary: wish.primary))
        if wish.primary {
            Button { picked = wish } label: {
                VStack(spacing: 6) {
                    planet(symbol, diameter: d, iconSize: d * 0.4, glow: true)
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
                planet(symbol, diameter: d, iconSize: d * 0.4, glow: false).opacity(0.85)
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

    /// Step the gravity sim one frame: make sure a body exists per placement,
    /// then integrate to `t` under the central pull + the device-tilt field.
    /// Raw gravity goes in; the sim learns the rest pose itself, so only an
    /// active lean perturbs the orbits (upright, flat, or Simulator-zero all
    /// read as calm).
    private func stepSim(_ places: [Placement], t: TimeInterval) {
        // Bodies are keyed by SEED id — stable across re-ranks. (Wish ids are
        // freshly minted opportunity ids each rebuild; keying by them made a
        // re-ranked wish teleport to a newly-seeded slot.)
        sim.sync(places.map {
            ($0.wish.seed.id, $0.ring, $0.idx, $0.count,
             importance(of: $0.wish), captureFlag(for: $0.wish))
        })
        sim.syncMoons(moonOf.map { (id: $0.key, parentId: $0.value) })
        sim.step(to: t, tilt: sensed.gravity, paused: reduceMotion)
    }

    /// A related fly-by the user is choosing about.
    private struct MoonChoice {
        let seedId: String, parentId: String, parentTitle: String, sugId: String
    }

    /// The seeds currently orbiting as moons whose parent is still a planet.
    private var activeMoonSeeds: [Seed] {
        moonOf.keys.compactMap { store.findSeed($0) }
            .filter { sim.isPlanet(moonOf[$0.id] ?? "") }
    }

    /// A moon's clamped screen position (read from the sim each frame).
    private func moonPosition(_ seedId: String, center: CGPoint, size: CGSize) -> CGPoint {
        let p = sim.screenPos(seedId, center: center) ?? center
        return CGPoint(x: clamp(p.x, 30, size.width - 30),
                       y: clamp(p.y, 90, size.height - 110))
    }

    /// Up to 2 related wishes (a sleeping seed sharing a category with a
    /// displayed primary, not already shown or a moon) to fling by as stars.
    private func relatedFlyBys() -> [Suggestion] {
        guard !isLateNight else { return [] }
        let shownIds = Set(displayed.map { $0.seed.id })
        let primaries = displayed.filter { $0.primary }
        var out: [Suggestion] = []
        for seed in store.seeds where seed.status == .sleeping
            && !shownIds.contains(seed.id) && moonOf[seed.id] == nil {
            guard let parent = primaries.first(where: {
                !Set($0.seed.categories).isDisjoint(with: Set(seed.categories))
            }) else { continue }
            out.append(Suggestion(
                id: "moon_\(seed.id)",
                emoji: Meta.category[seed.categories.first ?? .recovery]?.emoji ?? "🌙",
                title: seed.title,
                action: seed.minimumAction,
                category: seed.categories.first ?? .recovery,
                seedId: seed.id,
                moonParentId: parent.seed.id,
                moonParentTitle: parent.seed.title))
            if out.count == 2 { break }
        }
        return out
    }

    /// An important wish you'd set aside (sleeping) flees back in and is captured
    /// into orbit on its first appearance. Gentle & occasional; off when Reduce
    /// Motion is on.
    private func captureFlag(for wish: Wish) -> Bool {
        !reduceMotion && wish.seed.status == .sleeping && importance(of: wish) > 0.5
    }

    /// A wish's importance ∈ [0,1] — its recommendation score normalized across
    /// the displayed set. Drives planet size (bigger) and orbit radius (closer
    /// to the glass). Ambient wishes (no live opportunity) sit low.
    private func importance(of wish: Wish) -> Double {
        let scores = displayed.compactMap { $0.opp?.score }
        guard let lo = scores.min(), let hi = scores.max() else {
            return wish.primary ? 0.6 : 0.2
        }
        guard let s = wish.opp?.score else { return 0.15 }
        return PlanetPhysics.normalizedImportance(score: s, min: lo, max: hi)
    }

    /// Read a body's simulated screen position (clamped on-screen). Falls back to
    /// the orb centre if the body isn't seeded yet.
    private func simPosition(_ pl: Placement, center: CGPoint, size: CGSize) -> CGPoint {
        let p = sim.screenPos(pl.wish.seed.id, center: center) ?? center
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
        // Places already shown as badges on the displayed wishes never repeat
        // as scouted stars — each surface points somewhere different.
        let badgePlaces = Set(displayed.compactMap { matchedPlace(for: $0.seed)?.name })
        let scouted = OpportunityScout.scout(
            seeds: store.seeds,
            spots: sensed.nearby.compactMap { p in
                p.kind.map { OpportunityScout.Spot(name: p.name, kind: $0, distanceM: p.distanceM) }
            },
            hour: hour,
            isLateNight: isLateNight,
            excludedPlaces: badgePlaces
        )
        var base = Suggester.suggest(
            hour: hour,
            isLateNight: isLateNight,
            weather: sensed.weatherKind,
            activity: sensed.activity,
            nearbyCafe: sensed.nearbyCafe,
            nearbyOuting: sensed.nearbyOuting
        )
        // The scout already points at real places — the generic go-somewhere
        // suggestions would just overlap it.
        if !scouted.isEmpty {
            base.removeAll { $0.id == "s_cafe" || $0.id == "s_errand" }
        }
        // scout finds > related-moon fly-bys > model's moments > the static floor
        let ai = isLateNight ? [] : aiMoments
        let moons = relatedFlyBys()
        return Array((scouted + moons + ai + base)
            .filter { !caughtIds.contains($0.id) }.prefix(3))
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
                ForEach(items) { s in
                    // Lane + phase are hashed from the suggestion itself, so a
                    // reordered list never makes a star switch lines mid-flight.
                    let lane = Double(Int(Scoring.stableSerendipity(s.id, "lane") * 3))
                    let prog = reduceMotion
                        ? 0.4
                        : (t / 16.0 + lane * 0.33).truncatingRemainder(dividingBy: 1)
                    if prog < 0.85 {
                        let f = CGFloat(prog / 0.85)
                        // Star lanes stay in the sky band, above the orbit zone.
                        let start = CGPoint(x: size.width * 1.08, y: size.height * (0.07 + lane * 0.05))
                        let end = CGPoint(x: size.width * 0.10, y: size.height * (0.20 + lane * 0.055))
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

    /// A place that suits this wish's nature (learn → library/cafe …). Each
    /// wish hashes to a different candidate so two wishes never share one spot.
    private func matchedPlace(for seed: Seed) -> NearbyPlace? {
        guard nearbyAppropriate else { return nil }
        var kinds = Set<PlaceKind>()
        for c in seed.categories { if let a = Scoring.placeAffinity[c] { kinds.formUnion(a) } }
        let candidates = sensed.nearby.filter { p in p.kind.map { kinds.contains($0) } ?? false }
        guard !candidates.isEmpty else { return nil }
        var h: UInt64 = 5381
        for b in seed.id.utf8 { h = h &* 33 &+ UInt64(b) }
        return candidates[Int(h % UInt64(candidates.count))]
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
        case .attraction: return "好玩的去处"; case .nature: return "山水"
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
                    // Directions grown from the day: nearby places + motion +
                    // hour propose what kind of words suit right now.
                    let scenarios = LanguageScenarios.options(
                        nearby: nearbyAppropriate ? sensed.nearbyKinds : [],
                        activity: sensed.activity, hour: hour)
                    HStack(spacing: 6) {
                        ForEach(scenarios, id: \.self) { s in
                            Button { aiTheme = (aiTheme == s ? nil : s) } label: {
                                Text(s).font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(aiTheme == s ? theme.accentSoft : theme.surfaceSoft)
                                    .foregroundStyle(aiTheme == s ? theme.accentText : theme.textSecondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button { runAI(language: lang) } label: {
                        HStack(spacing: 6) {
                            if aiLoading { ProgressView().controlSize(.small) }
                            else { Image(systemName: "sparkles") }
                            Text(aiLoading ? "正在挑词…"
                                 : (aiTheme.map { "挑三个「\($0)」的\(lang)词" } ?? "让 AI 帮我挑三个\(lang)词"))
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
        let context = aiTheme.map { aiContext() + "；主题：\($0)" } ?? aiContext()
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
        // A related fly-by → offer: become a moon of X, or a separate star.
        if let sid = s.seedId, let pid = s.moonParentId {
            moonChoice = MoonChoice(seedId: sid, parentId: pid,
                                    parentTitle: s.moonParentTitle ?? "", sugId: s.id)
            return
        }
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
                PlanSectionView(seed: seed, onPhoto: { picked = nil; showTranslate = true })
                ExecutorSection(seed: seed)

                // The pursuit's journal page lives one tap away.
                Button {
                    picked = nil
                    path.append(Route.seedDetail(seed.id))
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed")
                        Text("打开它的手帐")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11))
                    }
                    .foregroundStyle(theme.textPrimary)
                    .padding(.vertical, 10).padding(.horizontal, Spacing.md)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

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

        // A completed/partial wish grows one part on today's little machine —
        // ask how it felt once the wish sheet has stepped aside. Skipped adds
        // nothing (and takes nothing).
        if kind != .skipped {
            let doneSeed = seed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                ratingSeed = doneSeed
            }
        }

        // 记忆星座: the wish falls into the black hole and is reborn as a
        // permanent star in the sky. Partial counts exactly the same — every
        // moment of presence earns its light.
        if skin == .glass, kind != .skipped, !reduceMotion, canvasSize != .zero {
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.52)
            let from = sim.screenPos(wish.seed.id, center: center)
                ?? CGPoint(x: center.x, y: center.y + 120)
            birth = StarBirth(traceId: trace.id,
                              category: trace.category,
                              from: from,
                              start: Date(),
                              to: ConstellationSky.position(for: trace.id, in: canvasSize))
        }
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
