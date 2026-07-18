//
//  MapPinboardView.swift
//  Luminous
//
//  A soft map workbench for travel days: paste a link, turn it into a map
//  search, correct by hand when needed, then keep only the pins that matter.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapPinboardView: View {
    @Environment(\.theme) private var theme

    @State private var pins: [TravelPin] = TravelPin.montrealStarter
    @State private var nearby: [TravelSearchResult] = []
    @State private var selectedPin: TravelPin?
    @State private var selectedResult: TravelSearchResult?
    @State private var camera: MapCameraPosition = .region(.montrealDay)
    @State private var visibleRegion: MKCoordinateRegion = .montrealDay

    @State private var pastedText = ""
    @State private var draft: MapPlaceDraft?
    @State private var manualName = ""
    @State private var manualAddress = ""
    @State private var manualNote = ""
    @State private var status = "贴一段链接或文字，我会先把它整理成地图搜索词。"
    @State private var isWorking = false
    @State private var nearbyQuery = "coffee restaurant attraction"

    private var visiblePins: [TravelPin] {
        pins.filter { visibleRegion.contains($0.coordinate) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    PageHeader(
                        title: "地图去处",
                        subtitle: "把链接、地址和临时灵感先放到地图上。看到附近有什么，再决定要不要靠近一点。"
                    )

                    mapCard
                    pasteCard
                    manualCard
                    visiblePinsCard
                    nearbyCard
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("地图")
            .inlineNavTitle()
            .sheet(item: $selectedPin) { pin in
                TravelPinDetail(pin: pin)
            }
            .sheet(item: $selectedResult) { result in
                TravelResultDetail(result: result) {
                    addPin(from: result)
                }
            }
            .task {
                await refreshNearby()
            }
        }
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Map(position: $camera, selection: Binding(
                get: { selectedPin?.id },
                set: { id in
                    selectedPin = pins.first { $0.id == id }
                })
            ) {
                ForEach(pins) { pin in
                    Marker(pin.name, systemImage: pin.systemImage, coordinate: pin.coordinate)
                        .tint(pin.tint)
                        .tag(pin.id)
                }
                ForEach(nearby.prefix(10)) { result in
                    Marker(result.name, systemImage: "mappin.and.ellipse", coordinate: result.coordinate)
                        .tint(.gray)
                }
            }
            .frame(height: 340)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1))
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                Task { await refreshNearby() }
            }

            HStack(spacing: Spacing.sm) {
                SoftButton(title: "回到今天路线", variant: .soft, full: false) {
                    camera = .region(.montrealDay)
                    visibleRegion = .montrealDay
                }
                SoftButton(title: "查这片区域", full: false) {
                    Task { await refreshNearby() }
                }
            }
        }
        .padding(Spacing.sm)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private var pasteCard: some View {
        BreathingCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("从链接整理地点", systemImage: "link")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                TextEditor(text: $pastedText)
                    .frame(minHeight: 96)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(theme.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))

                if let draft {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draft.name).font(.system(size: 16, weight: .medium))
                        Text(draft.bestQuery)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.textSecondary)
                        if !draft.note.isEmpty {
                            Text(draft.note)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.textMuted)
                        }
                    }
                    .padding(Spacing.md)
                    .background(theme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.sm) {
                    SoftButton(title: isWorking ? "整理中..." : "整理链接", variant: .soft, full: false, enabled: !isWorking && !pastedText.trimmed.isEmpty) {
                        Task { await draftFromPaste() }
                    }
                    SoftButton(title: "搜索并加 pin", full: false, enabled: draft != nil && !isWorking) {
                        Task { await addDraftPin() }
                    }
                }
            }
        }
    }

    private var manualCard: some View {
        BreathingCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("手动修正地址", systemImage: "mappin")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                TextField("地点名", text: $manualName)
                    .textFieldStyle(.roundedBorder)
                TextField("地址或搜索词", text: $manualAddress)
                    .textFieldStyle(.roundedBorder)
                TextField("小备注", text: $manualNote)
                    .textFieldStyle(.roundedBorder)

                SoftButton(title: "按地址加 pin", enabled: !manualAddress.trimmed.isEmpty) {
                    Task { await addManualPin() }
                }
            }
        }
    }

    private var visiblePinsCard: some View {
        BreathingCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Label("当前视野里的 pin", systemImage: "scope")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("\(visiblePins.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }

                if visiblePins.isEmpty {
                    Text("这片地图里还没有你保存的点。拖动地图，或者先加一个。")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    ForEach(visiblePins) { pin in
                        Button { selectedPin = pin } label: {
                            pinRow(pin)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var nearbyCard: some View {
        BreathingCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Label("这片区域可捡起的地点", systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                TextField("coffee, brunch, museum, park...", text: $nearbyQuery)
                    .textFieldStyle(.roundedBorder)

                if nearby.isEmpty {
                    Text("拖到想看的范围，再点「查这片区域」。")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    ForEach(nearby.prefix(8)) { result in
                        Button { selectedResult = result } label: {
                            resultRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func pinRow(_ pin: TravelPin) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: pin.systemImage)
                .foregroundStyle(pin.tint)
                .frame(width: 32, height: 32)
                .background(theme.surfaceSoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(pin.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Text(pin.address.isEmpty ? pin.note : pin.address)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textMuted)
        }
        .padding(.vertical, 6)
    }

    private func resultRow(_ result: TravelSearchResult) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "plus.circle")
                .foregroundStyle(theme.accentText)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Text(result.address)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func draftFromPaste() async {
        isWorking = true
        status = "正在把它变成地图能听懂的搜索词..."
        draft = await MapPinboardAI.draft(from: pastedText)
        if let draft {
            manualName = draft.name
            manualAddress = draft.bestQuery
            manualNote = draft.note
            status = AIHelper.isAvailable ? "已经整理好。你可以直接搜索，也可以先改地址。" : "端上智能不可用，先用文字里的线索做了保守草稿。"
        }
        isWorking = false
    }

    @MainActor
    private func addDraftPin() async {
        guard let draft else { return }
        isWorking = true
        await searchAndAdd(name: draft.name, query: draft.bestQuery, note: draft.note, source: pastedText.firstURLString)
        isWorking = false
    }

    @MainActor
    private func addManualPin() async {
        isWorking = true
        await searchAndAdd(name: manualName, query: manualAddress, note: manualNote, source: nil)
        isWorking = false
    }

    @MainActor
    private func searchAndAdd(name: String, query: String, note: String, source: String?) async {
        guard let result = await TravelMapSearch.first(query: query, region: visibleRegion) else {
            status = "地图没找到这个地址。换一个更具体的店名、城市或街道试试。"
            return
        }
        let pin = TravelPin(
            name: name.trimmed.isEmpty ? result.name : name.trimmed,
            kind: .custom,
            coordinate: result.coordinate,
            address: result.address,
            note: note.trimmed,
            source: source,
            mapItem: result.mapItem
        )
        pins.append(pin)
        selectedPin = pin
        camera = .region(MKCoordinateRegion(center: result.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)))
        status = "已加到地图。"
    }

    @MainActor
    private func refreshNearby() async {
        nearby = await TravelMapSearch.nearby(query: nearbyQuery, region: visibleRegion, excluding: pins.map(\.name))
    }

    @MainActor
    private func addPin(from result: TravelSearchResult) {
        let pin = TravelPin(
            name: result.name,
            kind: .custom,
            coordinate: result.coordinate,
            address: result.address,
            note: "从当前地图视野里捡起",
            source: nil,
            mapItem: result.mapItem
        )
        pins.append(pin)
        selectedPin = pin
    }
}

private struct TravelPinDetail: View {
    @Environment(\.theme) private var theme
    let pin: TravelPin

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PageHeader(title: pin.name, subtitle: pin.address.isEmpty ? nil : pin.address)
                if !pin.note.isEmpty {
                    Text(pin.note)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.textSecondary)
                }
                SoftButton(title: "在 Apple Maps 打开") { pin.openInMaps() }
                SoftButton(title: "用 Google Maps 搜索", variant: .soft) { pin.openInGoogleMaps() }
                if let source = pin.source, !source.isEmpty {
                    Link("原始链接", destination: URL(string: source) ?? URL(string: "https://www.google.com")!)
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accentText)
                }
                Spacer()
            }
            .padding(Spacing.lg)
            .themedScreen()
            .navigationTitle("地点")
            .inlineNavTitle()
        }
        .presentationDetents([.medium, .large])
    }
}

private struct TravelResultDetail: View {
    @Environment(\.theme) private var theme
    let result: TravelSearchResult
    let onAdd: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                PageHeader(title: result.name, subtitle: result.address)
                SoftButton(title: "加到 pin") { onAdd() }
                SoftButton(title: "在 Apple Maps 打开", variant: .soft) { result.mapItem.openInMaps() }
                Spacer()
            }
            .padding(Spacing.lg)
            .themedScreen()
            .navigationTitle("附近地点")
            .inlineNavTitle()
        }
        .presentationDetents([.medium])
    }
}

private struct TravelPin: Identifiable, Hashable {
    enum Kind: String, Hashable { case food, leisure, event, transport, custom }

    var id = UUID()
    var name: String
    var kind: Kind
    var coordinate: CLLocationCoordinate2D
    var address: String
    var note: String
    var source: String?
    var mapItem: MKMapItem?

    static func == (lhs: TravelPin, rhs: TravelPin) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var systemImage: String {
        switch kind {
        case .food: return "fork.knife"
        case .leisure: return "sparkles"
        case .event: return "fireworks"
        case .transport: return "tram.fill"
        case .custom: return "mappin"
        }
    }

    var tint: Color {
        switch kind {
        case .food: return .red
        case .leisure: return .green
        case .event: return .purple
        case .transport: return .blue
        case .custom: return .orange
        }
    }

    func openInMaps() {
        let item = mapItem ?? MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        item.openInMaps()
    }

    func openInGoogleMaps() {
        let query = [name, address].filter { !$0.isEmpty }.joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)") {
            #if os(iOS)
            UIApplication.shared.open(url)
            #else
            NSWorkspace.shared.open(url)
            #endif
        }
    }

    static let montrealStarter: [TravelPin] = [
        .init(name: "Sutton Village", kind: .leisure, coordinate: .init(latitude: 45.1060, longitude: -72.6163), address: "Rue Principale, Sutton, QC", note: "Village anchor for coffee, bakery, galleries, and a short walk.", source: nil, mapItem: nil),
        .init(name: "Auberge Sutton Brouerie", kind: .food, coordinate: .init(latitude: 45.1047, longitude: -72.6152), address: "27 Rue Principale S, Sutton", note: "Forgiving early dinner window before driving toward Montreal.", source: nil, mapItem: nil),
        .init(name: "Mont SUTTON", kind: .leisure, coordinate: .init(latitude: 45.1041, longitude: -72.5607), address: "671 Rue Maple, Sutton", note: "Chairlift and scenery; leave by late afternoon.", source: nil, mapItem: nil),
        .init(name: "Fort Chambly", kind: .leisure, coordinate: .init(latitude: 45.4488, longitude: -73.2804), address: "2 Rue de Richelieu, Chambly", note: "Fallback heritage/waterfront stop.", source: nil, mapItem: nil),
        .init(name: "Le Canal", kind: .food, coordinate: .init(latitude: 45.4728, longitude: -73.8640), address: "4945 Boulevard Saint-Jean, Pierrefonds", note: "Seafood alternative; too far west to pair cleanly with Sutton.", source: nil, mapItem: nil),
        .init(name: "REM Brossard", kind: .transport, coordinate: .init(latitude: 45.4307, longitude: -73.4381), address: "8200 Boulevard de Rome, Brossard", note: "Park-and-ride for Old Port fireworks.", source: nil, mapItem: nil),
        .init(name: "Grand Quay", kind: .event, coordinate: .init(latitude: 45.5021, longitude: -73.5529), address: "200 Rue de la Commune O, Montreal", note: "Official Old Port fireworks viewing anchor.", source: nil, mapItem: nil),
        .init(name: "Clock Tower Beach", kind: .event, coordinate: .init(latitude: 45.5104, longitude: -73.5482), address: "Clock Tower Beach, Montreal", note: "Ticketed fireworks-viewing option.", source: nil, mapItem: nil),
    ]
}

private struct TravelSearchResult: Identifiable {
    var id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
    var address: String
    var mapItem: MKMapItem
}

private enum TravelMapSearch {
    static func first(query: String, region: MKCoordinateRegion) async -> TravelSearchResult? {
        await search(query: query, region: region, limit: 1).first
    }

    static func nearby(query: String, region: MKCoordinateRegion, excluding names: [String]) async -> [TravelSearchResult] {
        let found = await search(query: query.trimmed.isEmpty ? "restaurant cafe attraction" : query, region: region, limit: 14)
        let excluded = Set(names.map { $0.lowercased() })
        return found.filter { !excluded.contains($0.name.lowercased()) }
    }

    private static func search(query: String, region: MKCoordinateRegion, limit: Int) async -> [TravelSearchResult] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        req.region = region
        req.resultTypes = [.pointOfInterest, .address]
        do {
            let response = try await MKLocalSearch(request: req).start()
            return response.mapItems.compactMap { item in
                guard let name = item.name,
                      let loc = item.placemark.location else { return nil }
                return TravelSearchResult(
                    name: name,
                    coordinate: loc.coordinate,
                    address: item.placemark.compactAddress,
                    mapItem: item
                )
            }
            .prefix(limit)
            .map { $0 }
        } catch {
            return []
        }
    }
}

private extension MKCoordinateRegion {
    static let montrealDay = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.42, longitude: -73.30),
        span: MKCoordinateSpan(latitudeDelta: 1.25, longitudeDelta: 2.1)
    )

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latMin = center.latitude - span.latitudeDelta / 2
        let latMax = center.latitude + span.latitudeDelta / 2
        let lonMin = center.longitude - span.longitudeDelta / 2
        let lonMax = center.longitude + span.longitudeDelta / 2
        return (latMin...latMax).contains(coordinate.latitude)
            && (lonMin...lonMax).contains(coordinate.longitude)
    }
}

private extension MKPlacemark {
    var compactAddress: String {
        let parts = [
            subThoroughfare,
            thoroughfare,
            locality,
            administrativeArea,
            postalCode
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }
}

private extension String {
    var firstURLString: String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(startIndex..<endIndex, in: self)
        return detector?.firstMatch(in: self, options: [], range: range)?.url?.absoluteString
    }
}

#if os(macOS)
import AppKit
#endif
