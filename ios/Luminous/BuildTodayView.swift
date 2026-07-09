//
//  BuildTodayView.swift
//  Luminous — 今天的小机器: the day-object screen.
//
//  CP-B: reachable from Home, shows the SceneKit stage. CP-C: today's parts
//  attach. CP-D: 播放今天 — a gentle ~10s scene chosen by the hour + weather.
//  The keepsake (CP-E) builds on this. A machine with one part is a WHOLE
//  little thing — the copy never asks for "more built", never counts.
//

import SwiftUI

struct BuildTodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(SensedSignals.self) private var sensed
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    @State private var playSignal = 0
    @State private var sceneLine: String?
    @State private var keptLine: String?

    private var hour: Int { Calendar.current.component(.hour, from: Date()) }
    private var soften: Bool {
        switch sensed.weatherKind {
        case .rain, .snow, .fog: return true
        default: return false
        }
    }

    var body: some View {
        let obj = store.todayObject()
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("今天的小机器")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                DayObjectStage(
                    tokens: theme,
                    parts: obj.parts,
                    reduceMotion: reduceMotion,
                    playSignal: playSignal,
                    skyColors: DayGrade.colors(hour: hour),
                    soften: soften)
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
                    .padding(.horizontal, Spacing.md)

                Text(sceneLine ?? caption(obj))
                    .font(.system(size: 15)).lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: 300)
                    .transition(.opacity)

                if !obj.isEmpty {
                    HStack(spacing: Spacing.md) {
                        // Play today — a gentle scene (only if motion is on).
                        if !reduceMotion {
                            Button {
                                playSignal += 1
                                withAnimation(.easeInOut) { sceneLine = playLine() }
                            } label: {
                                pill("play.circle", "播放今天")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("播放今天")
                            .accessibilityHint("看它在一个安静的小场景里动一会儿")
                        }
                        // Keep today into 痕迹 — a rendered keepsake.
                        Button {
                            let png = DayObjectSnapshot.png(tokens: theme, parts: obj.parts)
                            store.keepToday(snapshot: png)
                            withAnimation(.easeInOut) {
                                keptLine = "今天收好了。它会留在你的痕迹里。"
                            }
                        } label: {
                            pill("tray.and.arrow.down", "收进今天的痕迹")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("收进今天的痕迹")
                        .accessibilityHint("把今天的小机器收好，留在你的痕迹里")
                    }
                }

                if let keptLine {
                    Text(keptLine)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textMuted)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.top, Spacing.xl)
        }
        .hiddenNavBar()
    }

    private func pill(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 16, weight: .light))
            Text(label).font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(theme.accentText)
        .padding(.horizontal, Spacing.md).padding(.vertical, 10)
        .background(theme.accentSoft)
        .clipShape(Capsule())
    }

    /// Warm, count-free. Empty stage invites the first small thing; once it has
    /// grown, we say it moved — never how many parts, never "incomplete".
    private func caption(_ obj: DayObject) -> String {
        obj.isEmpty
            ? "今天还空着。完成一件很小的事，它就会长出一个零件，动一下。"
            : "它已经动起来了。今天没有完全消失。"
    }

    /// A soft scene line by the hour — matches the ~10s Play scene.
    private func playLine() -> String {
        let base: String
        switch DayGrade.phase(hour: hour) {
        case .dawn, .morning:      base = "清晨的花园小路上，它慢慢走了一段。"
        case .noon, .afternoon:    base = "它穿过白天的云，飘了一会儿。"
        case .dusk:                base = "傍晚的水面上，它轻轻漂着。"
        case .night:               base = "夜空下，它安静地滑过。"
        }
        return soften ? base + "外面有点雨，光是柔的。" : base
    }
}
