//
//  WishCalendarView.swift
//  Luminous — 《今天别消失》 / Today Don't Disappear
//
//  A calendar-stack view of ALL on-device wishes. Seven soft day stacks —
//  one per weekday a wish was *caught* (Mon…Sun) — with each wish flying in
//  as a small card and settling into its pile like a recipe card placed on a
//  stack. Heavier stacks read stronger (wider, thicker, more saturated badge).
//
//  This is NOT a schedule. The seven columns are a gentle way to look back at
//  where the week's wishes landed — no due dates, no overdue, no priority.
//
//  It doubles as an M-chip showcase: ~90 sample wishes fly in in parallel,
//  smoothly, with staggered spring landings and no per-frame heavy work.
//
//  Reached from Settings → "愿望日历".
//

import SwiftUI

// MARK: - Color sensing (readability first)

/// A tiny, dependency-free color model used for every generated card /
/// background color. It knows its own perceived brightness (luminance) and
/// hands back the text color that will read on top of it — so we never assume
/// "green means white text." Works across light green, tree green, amber,
/// blue, cream, and dark cards.
struct DemoRGBColor {
    let red: Double
    let green: Double
    let blue: Double

    /// Relative luminance (Rec. 709 coefficients), 0 (black) … 1 (white).
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    /// The legible text color for this background: white on dark, black on light.
    var contrastingText: Color { luminance < 0.5 ? .white : .black }

    var swiftUIColor: Color { Color(red: red, green: green, blue: blue) }

    /// A gently darker sibling (for the pile's shadowed under-layers).
    func darkened(_ amount: Double = 0.14) -> DemoRGBColor {
        DemoRGBColor(red: max(0, red - amount),
                     green: max(0, green - amount),
                     blue: max(0, blue - amount))
    }
}

/// Choose the text color that reads on top of an arbitrary SwiftUI `Color` by
/// resolving its RGB and measuring luminance. Used for stack labels and any
/// title drawn over a theme surface whose brightness we don't know ahead of time.
func contrastingTextColor(for background: Color) -> Color {
    #if canImport(UIKit)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(background).getRed(&r, green: &g, blue: &b, alpha: &a)
    #elseif canImport(AppKit)
    let ns = NSColor(background).usingColorSpace(.sRGB) ?? NSColor(background)
    let r = ns.redComponent, g = ns.greenComponent, b = ns.blueComponent
    #else
    let r: CGFloat = 0.5, g: CGFloat = 0.5, b: CGFloat = 0.5
    #endif
    return DemoRGBColor(red: Double(r), green: Double(g), blue: Double(b)).contrastingText
}

// MARK: - Category → warm color

enum WishPalette {
    /// A warm, handmade spread — deliberately spanning light green, tree green,
    /// amber, blue, cream, sage, and a dark so the contrast util is exercised.
    static func color(for category: SeedCategory) -> DemoRGBColor {
        switch category {
        case .body:        return DemoRGBColor(red: 0.72, green: 0.85, blue: 0.66) // light green tea
        case .creation:    return DemoRGBColor(red: 0.95, green: 0.78, blue: 0.42) // amber
        case .connection:  return DemoRGBColor(red: 0.96, green: 0.89, blue: 0.80) // cream
        case .exploration: return DemoRGBColor(red: 0.53, green: 0.71, blue: 0.90) // sky blue
        case .recovery:    return DemoRGBColor(red: 0.80, green: 0.82, blue: 0.93) // pale lavender
        case .learning:    return DemoRGBColor(red: 0.26, green: 0.44, blue: 0.31) // tree green (dark)
        case .aesthetic:   return DemoRGBColor(red: 0.62, green: 0.68, blue: 0.47) // sage / olive
        }
    }

    static func color(for seed: Seed) -> DemoRGBColor {
        color(for: seed.categories.first ?? .recovery)
    }
}

// MARK: - Grouping

/// One weekday's pile of caught wishes.
private struct DayBucket: Identifiable {
    let id: Int            // 0 = Monday … 6 = Sunday
    let label: String      // 周一 …
    let seeds: [Seed]
    var count: Int { seeds.count }
}

private enum WishCalendar {
    static let weekdayLabels = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    private static let parser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let parserFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func date(_ iso: String) -> Date {
        parser.date(from: iso) ?? parserFractional.date(from: iso) ?? Date()
    }

    /// Monday-first weekday index 0…6 for an ISO date string.
    static func mondayIndex(_ iso: String) -> Int {
        let wd = Calendar.current.component(.weekday, from: date(iso)) // 1=Sun…7=Sat
        return (wd + 5) % 7
    }

    /// Monday-first weekday index for today.
    static var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    /// Group all wishes into the seven weekday piles, newest-caught last so the
    /// pile builds bottom→top like placing cards.
    static func buckets(from seeds: [Seed]) -> [DayBucket] {
        var byDay: [Int: [Seed]] = [:]
        for s in seeds { byDay[mondayIndex(s.createdAt), default: []].append(s) }
        return (0..<7).map { day in
            let ordered = (byDay[day] ?? []).sorted { date($0.createdAt) < date($1.createdAt) }
            return DayBucket(id: day, label: weekdayLabels[day], seeds: ordered)
        }
    }
}

// MARK: - The screen

struct WishCalendarView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    /// In-memory demo wishes (DEBUG showcase). Never persisted — they live only
    /// as long as this view. `nil` → show the real, on-device `store.seeds`.
    @State private var demoSeeds: [Seed]? = nil
    @State private var selected: Seed? = nil

    private var displaySeeds: [Seed] { demoSeeds ?? store.seeds }
    private var buckets: [DayBucket] { WishCalendar.buckets(from: displaySeeds) }
    private var maxCount: Int { max(1, buckets.map(\.count).max() ?? 1) }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        ForEach(buckets) { bucket in
                            DayStackColumn(bucket: bucket,
                                           maxCount: maxCount,
                                           available: geo.size.height - 120,
                                           isToday: bucket.id == WishCalendar.todayIndex,
                                           onSelect: { selected = $0 })
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .themedScreen()
            .navigationTitle("愿望日历")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(theme.accentText)
                }
                #if DEBUG
                ToolbarItem(placement: .primaryAction) {
                    Button(demoSeeds == nil ? "演示" : "真实") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            demoSeeds = demoSeeds == nil ? DemoWishes.make() : nil
                        }
                    }
                    .foregroundStyle(theme.accentText)
                }
                #endif
            }
            .overlay(alignment: .bottom) { footnote }
            .sheet(item: $selected) { seed in
                SelectedWishCard(seed: seed) { selected = nil }
            }
        }
        .onAppear {
            #if DEBUG
            if demoSeeds == nil,
               ProcessInfo.processInfo.arguments.contains("-demoWishes") {
                demoSeeds = DemoWishes.make()
            }
            #endif
        }
    }

    private var footnote: some View {
        Text("每一列是那天你接住的愿望 · 不是日程")
            .font(.system(size: 12))
            .foregroundStyle(theme.textMuted)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.md)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, Spacing.md)
    }
}

// MARK: - One day's stack

private struct DayStackColumn: View {
    @Environment(\.theme) private var theme

    let bucket: DayBucket
    let maxCount: Int
    let available: CGFloat
    var isToday: Bool = false
    let onSelect: (Seed) -> Void

    @State private var isOpen = false

    /// 0…1 heaviness of this pile relative to the busiest day.
    private var weight: Double { Double(bucket.count) / Double(maxCount) }
    /// Heavier piles read wider.
    private var cardWidth: CGFloat { 132 + 44 * weight }
    /// Closed piles overlap tightly; open piles spread just enough to read every
    /// title, capped so the whole pile always fits the available height.
    private var closedStep: CGFloat { 16 }
    private var openStep: CGFloat {
        guard bucket.count > 1 else { return 0 }
        let room = max(120, available - cardHeight - 40)
        return min(46, room / CGFloat(bucket.count - 1))
    }
    private var step: CGFloat { isOpen ? openStep : closedStep }
    private var cardHeight: CGFloat { 62 }
    private var stackHeight: CGFloat {
        cardHeight + step * CGFloat(max(0, bucket.count - 1))
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            header
            stack
            Spacer(minLength: 0)
        }
        .frame(width: cardWidth + 24)
        .contentShape(Rectangle())
        // macOS / iPad pointer: the pile splits open like a finger in a book.
        .onHover { hovering in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { isOpen = hovering }
        }
        // iOS touch: tap the column to split it open / closed.
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { isOpen.toggle() }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Text(bucket.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isToday ? theme.accentText : theme.textPrimary)
            if isToday {
                Text("今天")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(theme.accentSoft, in: Capsule())
            }
            Spacer()
            CountBadge(count: bucket.count, weight: weight)
        }
        .padding(.horizontal, 4)
    }

    private var stack: some View {
        ZStack(alignment: .top) {
            // Physical "thickness" of the pile — a few offset plates behind the
            // cards, deeper on heavier days.
            thickness
            ForEach(Array(bucket.seeds.enumerated()), id: \.element.id) { idx, seed in
                WishStackCard(seed: seed,
                              index: idx,
                              step: step,
                              width: cardWidth,
                              height: cardHeight,
                              open: isOpen,
                              onTap: { onSelect(seed) })
                    .zIndex(Double(idx))
            }
            if bucket.count == 0 { emptyPile }
        }
        .frame(width: cardWidth + 20,
               height: max(cardHeight + 8, stackHeight + 8),
               alignment: .top)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isOpen)
    }

    private var thickness: some View {
        let plates = min(5, bucket.count)
        let base = WishPalette.color(for: bucket.seeds.first ?? sampleSeed).darkened(0.18)
        return ZStack {
            ForEach(0..<max(0, plates), id: \.self) { i in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(base.swiftUIColor.opacity(0.35))
                    .frame(width: cardWidth - CGFloat(i) * 5, height: cardHeight)
                    .offset(y: -CGFloat(i) * 3 - 3)
            }
        }
    }

    private var emptyPile: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
            .frame(width: cardWidth, height: cardHeight)
            .overlay(Text("—").foregroundStyle(theme.textMuted))
    }
}

// MARK: - A single card in a pile

private struct WishStackCard: View {
    let seed: Seed
    let index: Int
    let step: CGFloat
    let width: CGFloat
    let height: CGFloat
    let open: Bool
    let onTap: () -> Void

    @State private var landed = false

    private var color: DemoRGBColor { WishPalette.color(for: seed) }
    private var textColor: Color { color.contrastingText }

    /// Deterministic per-card jitter so the pile looks handmade, not machined.
    private var seedHash: UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in seed.id.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }
    private var restRotation: Double { (Double(seedHash % 100) / 100 - 0.5) * 5 } // ±2.5°
    private var flyFromX: CGFloat { (seedHash & 1) == 0 ? -140 : 140 }

    /// The resting slot: cards climb up the pile by `step`, newest on top.
    private var restY: CGFloat { -CGFloat(index) * step }

    var body: some View {
        let topOfClosedPile = !open && index == 0        // fully readable at rest
        let showFullTitle = open || topOfClosedPile
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(color.swiftUIColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.darkened(0.22).swiftUIColor.opacity(0.5), lineWidth: 1)
            )
            .overlay(cardLabel(full: showFullTitle), alignment: .topLeading)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(open ? 0.22 : 0.14),
                    radius: open ? 8 : 5,
                    x: 0, y: open ? 5 : 3)
            .rotationEffect(.degrees(landed ? restRotation : restRotation + 8))
            .scaleEffect(landed ? 1 : 1.16)
            .offset(x: landed ? 0 : flyFromX,
                    y: landed ? restY : restY - 60)
            .opacity(landed ? 1 : 0)
            .onTapGesture(perform: onTap)
            .onAppear {
                // Stagger within the day so multiple stacks fill in parallel, and
                // each card is briefly the top card (title readable) before the
                // next lands on it and it compresses into the pile.
                let delay = Double(index) * 0.05 + Double(seedHash % 7) * 0.012
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(delay)) {
                    landed = true
                }
            }
    }

    private func cardLabel(full: Bool) -> some View {
        HStack(spacing: 4) {
            Text(Meta.category[seed.categories.first ?? .recovery]?.emoji ?? "•")
                .font(.system(size: 12))
            Text(seed.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(full ? 2 : 1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .foregroundStyle(textColor)          // contrast-picked for THIS card color
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .frame(width: width, alignment: .leading)
    }
}

// MARK: - Count badge (heaviness → color)

private struct CountBadge: View {
    @Environment(\.theme) private var theme
    let count: Int
    let weight: Double   // 0…1

    var body: some View {
        // Heavier days get a stronger, warmer badge; the number stays legible via
        // the contrast util regardless of how dark the badge grows.
        let bg = badgeColor
        Text("\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(count == 0 ? theme.textMuted : bg.contrastingText)
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 5)
            .background(
                Capsule().fill(count == 0 ? Color.clear : bg.swiftUIColor)
            )
            .overlay(
                Capsule().strokeBorder(count == 0 ? theme.border : .clear, lineWidth: 1)
            )
    }

    private var badgeColor: DemoRGBColor {
        // amber → deep tree-green as the pile grows heavier.
        let light = DemoRGBColor(red: 0.95, green: 0.80, blue: 0.45)
        let heavy = DemoRGBColor(red: 0.20, green: 0.38, blue: 0.28)
        let t = weight
        return DemoRGBColor(
            red: light.red + (heavy.red - light.red) * t,
            green: light.green + (heavy.green - light.green) * t,
            blue: light.blue + (heavy.blue - light.blue) * t)
    }
}

// MARK: - The lifted, fully-legible selected card

private struct SelectedWishCard: View {
    @Environment(\.theme) private var theme
    let seed: Seed
    let onClose: () -> Void

    private var color: DemoRGBColor { WishPalette.color(for: seed) }
    private var text: Color { color.contrastingText }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(Meta.category[seed.categories.first ?? .recovery]?.emoji ?? "•")
                    .font(.system(size: 22))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(text.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Text(seed.title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(text)
                .fixedSize(horizontal: false, vertical: true)
            if !seed.minimumAction.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最小一步")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(text.opacity(0.7))
                    Text(seed.minimumAction)
                        .font(.system(size: 16))
                        .foregroundStyle(text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: Spacing.sm) {
                ForEach(seed.categories, id: \.self) { c in
                    Text(Meta.category[c]?.label ?? c.rawValue)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(text.opacity(0.14)))
                        .foregroundStyle(text)
                }
            }
            .padding(.top, 2)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.swiftUIColor)
        .presentationDetents([.height(280)])
        .presentationBackground(color.swiftUIColor)
        .presentationCornerRadius(Radius.sheet)
    }
}

private let sampleSeed = Seed(
    id: "sample", rawText: "", title: "", description: nil,
    categories: [.recovery], minimumAction: "", estimatedDurationMin: 5,
    energyRequired: .low, locationType: .anywhere, preferredTimes: [],
    triggerConditions: [], status: .active,
    createdAt: DomainUtil.nowIso(), updatedAt: DomainUtil.nowIso())

// MARK: - DEBUG-only demo wishes (in-memory; never persisted)

#if DEBUG
enum DemoWishes {
    private static let titles: [SeedCategory: [String]] = [
        .body: ["吃一顿热饭", "早点睡一次", "喝够水", "走 2000 步", "拉伸五分钟", "晒十分钟太阳"],
        .creation: ["写三行代码笔记", "画一张小画", "写一段日记", "拼一段旋律", "改一版设计", "记一个点子"],
        .connection: ["给妈妈发条消息", "约朋友喝咖啡", "回一封久违的信", "说一句真心话", "打个电话回家"],
        .exploration: ["去市中心走走", "换一条路回家", "逛一家没去过的店", "坐地铁到终点站", "找一个新公园"],
        .recovery: ["坐一会野外", "什么都不做十分钟", "泡个热水澡", "关掉所有通知", "深呼吸一分钟"],
        .learning: ["记 3 个法语单词", "读一页书", "看懂一个模块", "学一个新词", "看十分钟纪录片"],
        .aesthetic: ["拍一张好看的照片", "整理书桌", "换一束花", "听一张老专辑", "布置一角灯光"],
    ]
    private static let actions = [
        "只做最小的一步，够了就算", "开始就好，不求做完", "五分钟，随时可以停",
        "一个动作，完成一个就算", "轻轻地做一点点",
    ]

    /// ~90 in-memory sample wishes spread across the last seven days and all
    /// categories — enough to make the parallel fly-in and heaviness visible.
    static func make(count: Int = 90) -> [Seed] {
        let cats = SeedCategory.allCases
        var out: [Seed] = []
        let cal = Calendar.current
        for i in 0..<count {
            let cat = cats[i % cats.count]
            let pool = titles[cat] ?? ["一个小愿望"]
            let title = pool[(i / cats.count) % pool.count]
            // Bias toward a few busy days so the piles differ in heaviness.
            let dayBias = [0, 0, 1, 2, 2, 2, 3, 4, 5, 5, 6]
            let daysAgo = dayBias[i % dayBias.count]
            let when = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let iso = ISO8601DateFormatter().string(from: when)
            out.append(Seed(
                id: "demo_\(i)", rawText: title, title: title, description: nil,
                categories: [cat], minimumAction: actions[i % actions.count],
                estimatedDurationMin: [5, 10, 15, 20, 30][i % 5],
                energyRequired: [.low, .medium, .high][i % 3],
                locationType: .anywhere, preferredTimes: [], triggerConditions: [],
                status: .active, createdAt: iso, updatedAt: iso))
        }
        return out
    }
}
#endif
