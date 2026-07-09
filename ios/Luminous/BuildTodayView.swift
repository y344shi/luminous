//
//  BuildTodayView.swift
//  Luminous — 今天的小机器: the day-object screen.
//
//  CP-B: reachable from Home, shows the empty SceneKit stage with a calm line.
//  Parts (CP-C), Play (CP-D), and the keepsake (CP-E) build on this. A machine
//  with one part is a WHOLE little thing — the copy never asks for "more built".
//

import SwiftUI

struct BuildTodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let obj = store.todayObject()
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("今天的小机器")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                DayObjectStage(tokens: theme, parts: obj.parts, reduceMotion: reduceMotion)
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
                    .padding(.horizontal, Spacing.md)

                Text(caption(obj))
                    .font(.system(size: 15)).lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: 300)

                Spacer()
            }
            .padding(.top, Spacing.xl)
        }
        .hiddenNavBar()
    }

    /// Warm, count-free. Empty stage invites the first small thing; once it has
    /// grown, we say it moved — never how many parts, never "incomplete".
    private func caption(_ obj: DayObject) -> String {
        obj.isEmpty
            ? "今天还空着。完成一件很小的事，它就会长出一个零件，动一下。"
            : "它已经动起来了。今天没有完全消失。"
    }
}
