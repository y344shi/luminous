//
//  PlacesToGoView.swift
//  Luminous — 去处 · 现在能去的
//
//  A craving for aliveness (swim / badminton / bike / a French class / meeting
//  people / somewhere to build) turned into REAL nearby places you could just go
//  to. Everything factual is grounded in MapKit — the venue, its distance, its
//  website (the real registration / schedule page) and phone. Nothing here is
//  invented: the app never fabricates a session time. The on-device / cloud model
//  only adds one gentle line of invitation, and it passes ForbiddenWords.
//
//  Philosophy: this is an OFFER, not a to-do. For someone with a stressful job and
//  no time, it must be easy to ignore — no streaks, no pressure, and it steps back
//  late at night. Tap a place → it's kept as a soft wish with the link attached.
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - real venues (MapKit-grounded)

/// One real place near you. `url` is the venue's own page — the accurate,
/// verifiable link where the drop-in schedule / registration actually lives.
struct OutingVenue: Identifiable {
    let id = UUID()
    let name: String
    let distanceM: Double
    let url: URL?
    let phone: String?
    let categoryLabel: String
    let mapItem: MKMapItem

    var distanceLabel: String {
        distanceM < 1000 ? "\(Int((distanceM / 50).rounded()) * 50)m"
                         : String(format: "%.1fkm", distanceM / 1000)
    }
    var telURL: URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }
}

/// One craving → a query MapKit understands, plus which kind of wish it becomes.
struct OutingKind: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let query: String
    let category: SeedCategory
    var venues: [OutingVenue] = []
    var searched = false
    var reason: String?          // gentle model-framed invitation (fallback below)
    var fallbackReason: String

    // Weighted toward places that actually RUN registered drop-in programs,
    // classes and camps — community / recreation centres, campus rec, the Y —
    // rather than commercial venues. These bundle the swim / badminton / classes
    // with real sign-up pages.
    static let all: [OutingKind] = [
        .init(id: "community", emoji: "🏫", label: "社区 · 康乐中心", query: "community recreation centre",
              category: .connection, fallbackReason: "康乐中心里常有可以直接进去的活动。"),
        .init(id: "university", emoji: "🎓", label: "大学 · 校园项目", query: "university recreation center",
              category: .learning,   fallbackReason: "去校园里坐坐，蹭一场讲座或活动。"),
        .init(id: "camp",    emoji: "⛺", label: "营地 · 训练营",   query: "summer camp day camp",
              category: .exploration, fallbackReason: "报一个短营，换换环境。"),
        .init(id: "ymca",    emoji: "🅨", label: "青年会 · YMCA",   query: "YMCA",
              category: .connection, fallbackReason: "这里有游泳、课程，也有人。"),
        .init(id: "french",  emoji: "🇫🇷", label: "法语 · 语言课",   query: "French language school",
              category: .learning,   fallbackReason: "去听一节课，慢慢来。"),
        .init(id: "pool",    emoji: "🏊", label: "泳池 · 羽毛球",   query: "public swimming pool badminton",
              category: .body,       fallbackReason: "游一会儿，或挥两拍。"),
    ]
}

enum OutingSearch {
    /// One real MKLocalSearch per craving (sequential — MapKit throttles concurrent
    /// searches). Returns nearest-first real venues; nothing is synthesized.
    static func venues(for kind: OutingKind, near coord: CLLocationCoordinate2D,
                       limit: Int = 3) async -> [OutingVenue] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = kind.query
        req.region = MKCoordinateRegion(center: coord,
                                        latitudinalMeters: 9000, longitudinalMeters: 9000)
        guard let resp = try? await MKLocalSearch(request: req).start() else { return [] }
        let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return resp.mapItems.compactMap { item -> OutingVenue? in
            guard let name = item.name, let loc = item.placemark.location else { return nil }
            let cat = SensedSignals.placeKind(item.pointOfInterestCategory)
                .map(SensedSignals.placeKindName) ?? ""
            return OutingVenue(name: name, distanceM: loc.distance(from: here),
                               url: item.url, phone: item.phoneNumber,
                               categoryLabel: cat, mapItem: item)
        }
        .filter { $0.distanceM <= 100_000 }     // nothing more than 100km away
        .sorted { $0.distanceM < $1.distanceM }
        .prefix(limit).map { $0 }
    }
}

private struct KindReasons: Codable { var reasons: [String: String] }

// MARK: - view

struct PlacesToGoView: View {
    @Environment(\.theme) private var theme
    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.openURL) private var openURL

    @State private var kinds = OutingKind.all
    @State private var loading = false
    @State private var loadedOnce = false
    @State private var savedIds: Set<UUID> = []

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var isLateNight: Bool { TimeOfDay.isLateNight(hour: hour) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                if isLateNight { lateNightNote }
                if sensed.coordinate == nil {
                    locationPrompt
                } else {
                    ForEach($kinds) { $kind in kindSection($kind) }
                    accuracyFootnote
                }
            }
            .padding(Spacing.lg)
        }
        .themedScreen()
        .navigationTitle("去处")
        .inlineNavTitle()
        .task { await loadIfNeeded() }
        .refreshable { await reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("现在能去的").font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Text("把“想动一动、想认识人、想学点什么”变成身边真的能去的地方——偏向社区康乐中心、大学项目和营地这类真的在办活动、可以报名的地方。都是地图上真实的场馆和它们自己的报名/排期链接，不着急，看一眼就好。")
                .font(.system(size: 13)).lineSpacing(3).foregroundStyle(theme.textSecondary)
        }
    }

    private var lateNightNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars").foregroundStyle(theme.textMuted)
            Text("夜深了。这些明天也都在——先照顾自己。")
                .font(.system(size: 13)).foregroundStyle(theme.textSecondary)
        }
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var locationPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("打开定位，就能看看你身边现在能去的地方。")
                .font(.system(size: 14)).foregroundStyle(theme.textSecondary)
            SoftButton(title: "刷新", variant: .ghost) {
                Task { sensed.refresh(); try? await Task.sleep(nanoseconds: 800_000_000); await loadIfNeeded() }
            }
        }
        .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var accuracyFootnote: some View {
        Text("开放时间、名额和报名都以场馆自己的页面为准（点“报名 · 排期”打开）。这里不编造时间。")
            .font(.system(size: 12)).lineSpacing(3).foregroundStyle(theme.textMuted)
            .padding(.top, 4)
    }

    @ViewBuilder private func kindSection(_ kind: Binding<OutingKind>) -> some View {
        let k = kind.wrappedValue
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 8) {
                Text(k.emoji).font(.system(size: 20))
                Text(k.label).font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            Text(k.reason ?? k.fallbackReason)
                .font(.system(size: 13)).foregroundStyle(theme.textSecondary)

            if !k.searched && k.venues.isEmpty {
                HStack(spacing: 8) { ProgressView(); Text("在找附近…")
                    .font(.system(size: 13)).foregroundStyle(theme.textMuted) }
            } else if k.venues.isEmpty {
                Text("附近暂时没找到——换个日子、或到大一点的城区再看看。")
                    .font(.system(size: 13)).foregroundStyle(theme.textMuted)
            } else {
                ForEach(k.venues) { v in venueCard(k, v) }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private func venueCard(_ kind: OutingKind, _ v: OutingVenue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(v.name).font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text(v.distanceLabel).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.accentText)
            }
            if !v.categoryLabel.isEmpty {
                Text(v.categoryLabel).font(.system(size: 12)).foregroundStyle(theme.textMuted)
            }
            // Real, linked actions — the source of truth for schedule/registration.
            HStack(spacing: 8) {
                if let u = v.url {
                    linkChip("报名 · 排期", "link") { openURL(u) }
                }
                if let tel = v.telURL {
                    linkChip("打电话", "phone") { openURL(tel) }
                }
                linkChip("路线", "map") { v.mapItem.openInMaps() }
            }
            Button {
                saveWish(kind, v)
            } label: {
                Label(savedIds.contains(v.id) ? "已记成小愿望" : "记成小愿望",
                      systemImage: savedIds.contains(v.id) ? "checkmark.circle.fill" : "leaf")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(savedIds.contains(v.id) ? theme.accentText : theme.textSecondary)
            }
            .buttonStyle(.plain).disabled(savedIds.contains(v.id))
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func linkChip(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium)).foregroundStyle(theme.accentText)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(theme.accent.opacity(0.14), in: Capsule())
        }.buttonStyle(.plain)
    }

    // MARK: work

    private func loadIfNeeded() async {
        sensed.refresh()
        guard sensed.coordinate != nil, !loadedOnce else { return }
        loadedOnce = true
        await reload()
    }

    private func reload() async {
        guard let coord = sensed.coordinate, !loading else { return }
        loading = true
        for i in kinds.indices {
            kinds[i].venues = await OutingSearch.venues(for: kinds[i], near: coord)
            kinds[i].searched = true
        }
        loading = false
        await frameReasons()
    }

    /// One optional cloud touch: a gentle one-line invitation per craving. It never
    /// carries facts (times/venues stay MapKit-grounded) and passes ForbiddenWords.
    private func frameReasons() async {
        guard CloudLLM.isConfigured else { return }
        let list = kinds.map { "\($0.id): \($0.label)" }.joined(separator: "；")
        let sys = "你在帮一个工作很累、时间不多的人，温柔地邀请他去做点让今天不消失的小事。别命令，别打鸡血，平静、简短。"
        let user = "为这些去处各写一句不超过18字的温柔邀请。返回 JSON：{\"reasons\": {\"swim\": \"...\", \"badminton\": \"...\"}}。类别：\(list)"
        guard let r: KindReasons = await CloudLLM.json(system: sys, user: user, as: KindReasons.self) else { return }
        for i in kinds.indices {
            if let s = r.reasons[kinds[i].id]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !s.isEmpty, ForbiddenWords.passes(s) {
                kinds[i].reason = s
            }
        }
    }

    private func saveWish(_ kind: OutingKind, _ v: OutingVenue) {
        let ts = DomainUtil.nowIso()
        var desc = "在 \(v.name) · \(v.distanceLabel)"
        if let u = v.url { desc += "\n报名 / 排期：\(u.absoluteString)" }
        let seed = Seed(
            id: DomainUtil.uid("seed"),
            rawText: "\(kind.label) · \(v.name)",
            title: "去 \(v.name)",
            description: desc,
            categories: [kind.category],
            minimumAction: "到门口就算数",
            estimatedDurationMin: 60,
            energyRequired: .medium,
            locationType: .outdoor,
            preferredTimes: [],
            triggerConditions: [],
            tags: [kind.label, v.name],
            status: .active,
            createdAt: ts, updatedAt: ts)
        store.addSeed(seed)
        savedIds.insert(v.id)
    }
}
