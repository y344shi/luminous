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

    private let orbR: CGFloat = 66

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var isLateNight: Bool { TimeOfDay.isLateNight(hour: hour) }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let size = geo.size
                let center = CGPoint(x: size.width / 2, y: size.height * 0.46)

                ZStack {
                    AestheticField(weather: sensed.weatherKind).ignoresSafeArea()

                    bloom.position(center)
                    orb.position(center)

                    ForEach(Array(shown.enumerated()), id: \.element.id) { idx, wish in
                        let p = position(for: wish, index: idx, center: center, size: size)
                        let lean = leanOffset(primary: wish.primary)
                        let drag = dragOffsets[wish.id] ?? .zero
                        bubble(wish)
                            .position(x: p.x + lean.width + drag.width,
                                      y: p.y + lean.height + drag.height)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 8)
                                    .onChanged { v in dragOffsets[wish.id] = v.translation }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                            dragOffsets[wish.id] = .zero
                                        }
                                    }
                            )
                            .animation(.easeOut(duration: 0.25), value: lean)
                    }

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

    private var orb: some View {
        Button { path.append(Route.now) } label: {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                Circle().fill(LinearGradient(
                    colors: [.white.opacity(0.30), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                VStack(spacing: 4) {
                    Image(systemName: sceneIcon)
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(theme.textPrimary)
                    Text(sceneLabel)
                        .font(.system(size: 11))
                        .tracking(2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(width: orbR * 2, height: orbR * 2)
            .shadow(color: theme.accent.opacity(0.25), radius: 18)
            .scaleEffect(breathe ? 1.03 : 0.99)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Copy.Home.primary)
    }

    // MARK: Wishes

    @ViewBuilder private func bubble(_ wish: Wish) -> some View {
        let emoji = Meta.category[wish.seed.categories.first ?? .recovery]?.emoji ?? "🫧"
        if wish.primary {
            Button { picked = wish } label: {
                VStack(spacing: 5) {
                    Text(emoji).font(.system(size: 38))
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    Text(wish.seed.title)
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 96)
                }
            }
            .buttonStyle(.plain)
        } else {
            Button { picked = wish } label: {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    Text(emoji).font(.system(size: 18))
                }
                .frame(width: 42, height: 42)
                .opacity(0.85)
            }
            .buttonStyle(.plain)
        }
    }

    /// Primaries settle in a ring round the orb; lesser wishes rest in stable
    /// pseudo-random spots across the field (derived from the seed id, not random
    /// each render). Everything is clamped to stay on screen.
    private func position(for wish: Wish, index: Int, center: CGPoint, size: CGSize) -> CGPoint {
        if wish.primary {
            let primaries = shown.filter { $0.primary }
            let n = max(primaries.count, 1)
            let i = primaries.firstIndex { $0.id == wish.id } ?? 0
            // ring radius large enough that a wish never overlaps the central orb.
            let radius = max(min(size.width, size.height) * 0.34, orbR + 96)
            let ang = (-90.0 + 360.0 / Double(n) * Double(i)) * .pi / 180
            let x = center.x + CGFloat(cos(ang)) * radius
            let y = center.y + CGFloat(sin(ang)) * radius
            return CGPoint(x: clamp(x, 60, size.width - 60), y: clamp(y, 110, size.height - 130))
        } else {
            let h = abs(wish.seed.id.hashValue)
            let fx = 0.10 + Double(h % 1000) / 1000 * 0.80
            let fy = 0.14 + Double((h / 1000) % 1000) / 1000 * 0.72
            var p = CGPoint(x: clamp(CGFloat(fx) * size.width, 40, size.width - 40),
                            y: clamp(CGFloat(fy) * size.height, 70, size.height - 110))
            // keep lesser dots clear of the central orb (push them outward).
            let minD = orbR + 64
            let dx = p.x - center.x, dy = p.y - center.y
            let d = max(sqrt(dx * dx + dy * dy), 0.001)
            if d < minD {
                p = CGPoint(x: center.x + dx / d * minD, y: center.y + dy / d * minD)
            }
            return p
        }
    }

    /// A gentle device-tilt lean for the floating wishes (zero on simulator).
    private func leanOffset(primary: Bool) -> CGSize {
        let amp: CGFloat = primary ? 16 : 22
        let g = sensed.gravity
        let dx = g.width * amp
        let dy = (g.height + 1.0) * amp * 0.6   // upright (g.y ≈ -1) → ~0
        return CGSize(width: clamp(dx, -amp, amp), height: clamp(dy, -amp, amp))
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
            suggestionsView
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

    @ViewBuilder private var suggestionsView: some View {
        let items = suggestions
        if !items.isEmpty {
            HStack(spacing: 16) {
                ForEach(items) { s in
                    Button { catchSuggestion(s) } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                Circle().fill(theme.accent.opacity(0.55))
                                    .frame(width: 48, height: 48)
                                    .blur(radius: 11)
                                    .scaleEffect(breathe ? 1.15 : 0.9)
                                Circle().fill(.ultraThinMaterial).frame(width: 40, height: 40)
                                Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1)
                                    .frame(width: 40, height: 40)
                                Text(s.emoji).font(.system(size: 20))
                            }
                            Text(s.title)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
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
            nearbyRow
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

    /// A gentle horizontal row of nearby places (cafe / store / market).
    @ViewBuilder private var nearbyRow: some View {
        if nearbyAppropriate && !sensed.nearby.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sensed.nearby) { place in
                        Button {
                            place.mapItem.openInMaps()
                        } label: {
                            HStack(spacing: 4) {
                                Text(place.emoji).font(.system(size: 13))
                                Text(place.name).font(.system(size: 12)).lineLimit(1)
                                Text(place.distanceLabel)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.textMuted)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .foregroundStyle(theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
        }
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
            weatherKind: sensed.weatherKind
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
            .prefix(3)
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
