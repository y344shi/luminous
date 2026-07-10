//
//  LinkHubView.swift
//  Luminous — 去处: a calm hub that ties the app's places together so the whole
//  thing reads as ONE connected space, not scattered buttons. Four soft cards —
//  愿望日历 · 手帐/想法 · 今天的小机器 · 痕迹 — each an icon, a name, and a
//  one-line feeling. Tapping one opens that surface. Count-free, skin-aware.
//

import SwiftUI

/// Where a hub card leads. The host (Home) knows how to reach each.
enum HubDestination: Identifiable {
    case calendar, notes, machine, traces
    var id: String { "\(self)" }
}

struct LinkHubView: View {
    var onOpen: (HubDestination) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private struct Place {
        let dest: HubDestination
        let icon: String
        let name: String
        let feeling: String
    }

    private let places: [Place] = [
        .init(dest: .calendar, icon: "calendar",
              name: "愿望日历", feeling: "这一周你接住的念头，一列一天"),
        .init(dest: .notes, icon: "book.closed",
              name: "手帐 · 想法", feeling: "每件长期的事，一页想法都放在这里"),
        .init(dest: .machine, icon: "cube.transparent",
              name: "今天的小机器", feeling: "今天做过的小事，长成一个会动的东西"),
        .init(dest: .traces, icon: "book",
              name: "痕迹", feeling: "那些你真的在场的时刻，一句句留下来"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    Text("这些地方，其实是同一个今天的不同侧面。")
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.sm)

                    ForEach(places, id: \.dest.id) { place in
                        Button {
                            onOpen(place.dest)
                        } label: {
                            hubCard(place)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(place.name)
                        .accessibilityHint(place.feeling)
                    }
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle("去处")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(theme.accentText)
                }
            }
        }
    }

    private func hubCard(_ place: Place) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: place.icon)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(theme.accentText)
                .frame(width: 52, height: 52)
                .background(theme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                Text(place.feeling)
                    .font(.system(size: 13)).lineSpacing(2)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.textMuted)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }
}
