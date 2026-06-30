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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { tl in
                        let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                        let places = placements()
                        ForEach(places, id: \.wish.id) { pl in
                            let p = orbitPosition(pl, t: t, center: center, size: size)
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
    private var orb: some View {
        Button { path.append(Route.now) } label: {
            let rs = orbR * 0.70   // shadow radius
            ZStack {
                // soft glow of the surrounding light
                Circle()
                    .fill(RadialGradient(colors: [hot.opacity(0.30), .clear],
                                         center: .center, startRadius: rs, endRadius: orbR * 1.9))
                    .blur(radius: 12)
                    .scaleEffect(breathe ? 1.05 : 0.98)

                // the far side of the disk, lensed up and over the top of the hole
                lensedArc(rs).blur(radius: 2)

                // the edge-on accretion disk (its wings extend past the shadow)
                accretionDisk(rs).blur(radius: 3)

                // the event-horizon shadow
                Circle().fill(.black).frame(width: rs * 2, height: rs * 2)

                // the near side of the disk passes in front of the shadow's lower half
                accretionDisk(rs)
                    .mask(Rectangle().frame(width: orbR * 2, height: rs).offset(y: rs * 0.5))
                    .blur(radius: 2)

                // photon ring hugging the shadow (brightest at top)
                Circle()
                    .stroke(AngularGradient(
                        colors: [hot, .white, hot, hot.opacity(0.5), hot],
                        center: .center, angle: .degrees(-90)), lineWidth: 2)
                    .frame(width: rs * 2 + 3, height: rs * 2 + 3)
                    .blur(radius: 0.4)

                // Doppler beaming — the approaching (left) side is brighter
                Ellipse()
                    .fill(RadialGradient(colors: [.white.opacity(0.6), .clear],
                                         center: .center, startRadius: 0, endRadius: rs))
                    .frame(width: rs * 1.5, height: rs * 0.55)
                    .offset(x: -rs * 0.85)
                    .blendMode(.plusLighter)
            }
            .frame(width: orbR * 2, height: orbR * 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.Home.primary)
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

    /// A planet's position: a slow elliptical orbit (outer = slower), plus a
    /// device-tilt "gravity" pull toward the lean (stronger on outer orbits).
    private func orbitPosition(_ pl: Placement, t: TimeInterval, center: CGPoint, size: CGSize) -> CGPoint {
        let R = orbR + 70 + CGFloat(pl.ring) * 50
        let omega = 2 * Double.pi / (90 + Double(pl.ring) * 30)   // seconds per turn
        let base = Double.pi / 2 + 2 * Double.pi / Double(max(pl.count, 1)) * Double(pl.idx)
        let angle = base + Double(pl.ring) * 0.6 + (reduceMotion ? 0 : t * omega)
        let ellipse: CGFloat = 0.82
        var x = center.x + CGFloat(cos(angle)) * R
        var y = center.y + CGFloat(sin(angle)) * R * ellipse
        // tilt = an extra pull star
        let amp: CGFloat = 14 * (1 + CGFloat(pl.ring) * 0.25)
        let g = sensed.gravity
        x += g.width * amp
        y += (g.height + 1.0) * amp * 0.7
        return CGPoint(x: clamp(x, 44, size.width - 44), y: clamp(y, 100, size.height - 120))
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

    /// Context-born suggestions, shown as glowing icons. Tap to catch one into
    /// the garden. Late night only ever offers calm stop-loss.
    private var suggestions: [Suggestion] {
        Suggester.suggest(
            hour: hour,
            isLateNight: isLateNight,
            weather: sensed.weatherKind,
            activity: sensed.activity,
            nearbyCafe: sensed.nearbyCafe,
            nearbyOuting: sensed.nearbyOuting
        ).filter { !caughtIds.contains($0.id) }
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
                        shootingStar(s)
                            .position(x: start.x + (end.x - start.x) * f,
                                      y: start.y + (end.y - start.y) * f)
                            .opacity(Double(min(1, min(f * 5, (1 - f) * 5))))
                    }
                }
            }
        }
    }

    private func shootingStar(_ s: Suggestion) -> some View {
        Button { catchSuggestion(s) } label: {
            VStack(spacing: 2) {
                ZStack {
                    // streak tail, trailing behind the leftward motion
                    Capsule()
                        .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 56, height: 2.5)
                        .offset(x: 32)
                        .blur(radius: 0.6)
                    Circle().fill(.white.opacity(0.5)).frame(width: 30, height: 30)
                        .blur(radius: 7).scaleEffect(breathe ? 1.2 : 0.9)
                    Text(s.emoji).font(.system(size: 17))
                }
                Text(s.title).font(.system(size: 9))
                    .foregroundStyle(theme.textSecondary).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .rotationEffect(.degrees(10))
    }

    /// The nearest place that suits this wish's nature (learn → library/cafe …).
    private func matchedPlace(for seed: Seed) -> NearbyPlace? {
        guard nearbyAppropriate else { return nil }
        var kinds = Set<PlaceKind>()
        for c in seed.categories { if let a = Scoring.placeAffinity[c] { kinds.formUnion(a) } }
        return sensed.nearby.first { p in p.kind.map { kinds.contains($0) } ?? false }
    }

    private func catchSuggestion(_ s: Suggestion) {
        Feedback.completion(.partial)   // a soft "caught" tap
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
                VStack(spacing: Spacing.sm) {
                    SoftButton(title: Copy.Completion.done) { complete(wish, .completed) }
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
        let opps = Scoring.recommend(store.seeds, ctx, limit: 3)
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
