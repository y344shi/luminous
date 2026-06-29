//
//  SettingsView.swift
//  Luminous
//
//  The "设置" tab — theme switcher, gentle-reminder toggle, reset.
//  Ported from components/settings/SettingsPanel.tsx + ThemeSwitcher.tsx.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    PageHeader(title: Copy.SettingsCopy.title)

                    skinSection
                    themeSection
                    nudgeSection
                    resetSection

                    Text(Copy.SettingsCopy.privacy)
                        .font(.system(size: 13)).lineSpacing(3)
                        .foregroundStyle(theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Spacing.sm)
                }
                .padding(Spacing.lg)
            }
            .themedScreen()
            .navigationTitle(Copy.Tab.settings)
            .inlineNavTitle()
            .confirmationDialog(
                Copy.SettingsCopy.resetConfirmTitle,
                isPresented: $confirmingReset,
                titleVisibility: .visible
            ) {
                Button(Copy.SettingsCopy.resetConfirmYes, role: .destructive) { store.resetAll() }
                Button(Copy.SettingsCopy.resetConfirmNo, role: .cancel) {}
            } message: {
                Text(Copy.SettingsCopy.resetConfirm)
            }
        }
    }

    // MARK: 外观风格 — the swappable skin (glass / ocean / paper)

    private var skinSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("外观风格")
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)

            // Follow system appearance: Dark → glass, Light → paper.
            Toggle(isOn: Binding(
                get: { store.aestheticAuto },
                set: { store.setAestheticAuto($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自动")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Text("跟随系统明暗 · 深色用玻璃，浅色用纸页")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(store.aestheticAuto ? theme.accent : theme.border, lineWidth: 1))

            ForEach(Aesthetic.allCases) { skin in
                skinRow(skin)
            }
        }
    }

    private func skinRow(_ skin: Aesthetic) -> some View {
        let autoActive = store.aestheticAuto && store.effectiveAesthetic(dark: colorScheme == .dark) == skin
        let selected = !store.aestheticAuto && store.aesthetic == skin
        return Button { store.setAesthetic(skin) } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: skin.symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(skin.label)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Text(skin.feeling)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if autoActive {
                    Text("自动")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? theme.accent : theme.border, lineWidth: 1))
            .opacity(store.aestheticAuto && !autoActive ? 0.5 : 1)
        }
        .buttonStyle(.plain)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(Copy.SettingsCopy.themeLabel)
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)
            ForEach(Theme.order, id: \.self) { name in
                themeRow(name)
            }
        }
    }

    private func themeRow(_ name: ThemeName) -> some View {
        let tokens = Theme.tokens(for: name)
        let style = Theme.style[name]
        let selected = store.theme == name
        return Button { store.setTheme(name) } label: {
            HStack(spacing: Spacing.md) {
                swatch(tokens)
                VStack(alignment: .leading, spacing: 2) {
                    Text(style?.label ?? name.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Text(style?.feeling ?? "")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? theme.accent : theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ tokens: ThemeTokens) -> some View {
        HStack(spacing: 0) {
            tokens.background
            tokens.surface
            tokens.accent
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private var nudgeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(Copy.SettingsCopy.nudgeLabel)
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)
            Toggle(isOn: Binding(
                get: { store.settings.nudgesEnabled },
                set: { v in store.updateSettings { $0.nudgesEnabled = v } }
            )) {
                Text(store.settings.nudgesEnabled
                     ? "在合适的时候，轻轻提醒你一下"
                     : "不主动提醒，你来找它就好")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.textPrimary)
            }
            .tint(theme.accent)
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1))
        }
    }

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SoftButton(title: Copy.SettingsCopy.resetLabel, variant: .ghost) {
                confirmingReset = true
            }
        }
    }
}
