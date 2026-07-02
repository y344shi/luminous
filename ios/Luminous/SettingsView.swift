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
    @Environment(SensedSignals.self) private var sensed
    @State private var confirmingReset = false
    @State private var namingGarden = false
    @State private var newGardenName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    PageHeader(title: Copy.SettingsCopy.title)

                    skinSection
                    senseSection
                    themeSection
                    nudgeSection
                    gardenSection
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

            // Theme music for the active skin.
            Toggle(isOn: Binding(
                get: { store.musicOn },
                set: { store.setMusicOn($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("主题音乐")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                    Text("每个外观一段轻音乐，轻轻地放着")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(store.musicOn ? theme.accent : theme.border, lineWidth: 1))

            Text("音乐 © Kevin MacLeod · incompetech.com · CC BY 4.0")
                .font(.system(size: 11))
                .foregroundStyle(theme.textMuted)
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

    // 感受周围 — opt in to coarse on-device sensing (location → weather).
    private var senseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("感受周围")
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)
            Toggle(isOn: Binding(
                get: { store.senseAround },
                set: { store.setSenseAround($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.senseAround ? "让它感受此刻的环境" : "只看时间，不感受环境")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.textPrimary)
                    Text("只在本机：粗略的位置→天气，帮我挑现在合适的事。不记录、不上传原始数据。")
                        .font(.system(size: 12)).lineSpacing(2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(store.senseAround ? theme.accent : theme.border, lineWidth: 1))

            sensingStatus
        }
    }

    /// A live read of which senses are feeding the recommendation right now.
    private var sensingStatus: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sourceRow("时间 · 光线", detail: "驱动此刻的天空与光", active: true)
            sourceRow("动作", detail: activityDetail, active: sensed.activity != nil)
            sourceRow("位置 → 天气", detail: weatherDetail, active: store.senseAround && sensed.weatherKind != nil)
            sourceRow("心率 → 状态", detail: "未接入（需要 HealthKit）", active: false)
            sourceRow("声音 → 安静/热闹", detail: "未接入（需要麦克风）", active: false)
            if let dwell = store.todayDwellLine() {
                Text(dwell)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textMuted)
                    .padding(.top, 2)
            }
        }
        .padding(Spacing.md)
        .background(theme.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sourceRow(_ name: String, detail: String, active: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(active ? Color.green : theme.textMuted.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var activityDetail: String {
        switch sensed.activity {
        case .still:   return "现在：坐着 / 静止"
        case .walking: return "现在：走着"
        case .transit: return "现在：在路上"
        case .none:    return "待机（动一下就会感受到）"
        }
    }

    private var weatherDetail: String {
        guard store.senseAround else { return "未开启" }
        switch sensed.weatherKind {
        case .clear:   return "现在：晴"
        case .clouds:  return "现在：多云"
        case .rain:    return "现在：有雨"
        case .snow:    return "现在：下雪"
        case .fog:     return "现在：有雾"
        case .unknown, .none: return "正在获取…"
        }
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

    // MARK: 花园 — several gardens on one device, each its own seeds & traces.

    private var gardenSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("花园")
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)
            ForEach(store.gardens) { g in
                Button { store.switchGarden(g.id) } label: {
                    HStack(spacing: Spacing.md) {
                        Image(systemName: "leaf")
                            .font(.system(size: 18))
                            .foregroundStyle(theme.accent)
                            .frame(width: 36, height: 36)
                            .background(theme.surfaceSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(g.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        if g.id == store.activeProfileID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .padding(Spacing.md)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(g.id == store.activeProfileID ? theme.accent : theme.border,
                                      lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            SoftButton(title: "新建一座花园", variant: .ghost) {
                newGardenName = ""
                namingGarden = true
            }
            Text("每座花园有自己的愿望和痕迹，适合家人共用一台设备。")
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
        }
        .alert("给新花园起个名字", isPresented: $namingGarden) {
            TextField("比如：妈妈的花园", text: $newGardenName)
            Button("种下") { store.createGarden(name: newGardenName) }
            Button("先不了", role: .cancel) {}
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
