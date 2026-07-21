//
//  SettingsView.swift
//  Luminous
//
//  The "设置" tab — theme switcher, gentle-reminder toggle, reset.
//  Ported from components/settings/SettingsPanel.tsx + ThemeSwitcher.tsx.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SensedSignals.self) private var sensed
    @State private var confirmingReset = false
    @State private var namingGarden = false
    @State private var newGardenName = ""
    @State private var showingCalendar = false
    @State private var voicePreview = Speaker()
    @State private var voiceRefresh = 0
    @State private var cloudBase = CloudLLM.baseURL
    @State private var cloudKey = CloudLLM.apiKey
    @State private var cloudModel = CloudLLM.model
    @State private var cloudTesting = false
    @State private var cloudTestResult: Bool? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    PageHeader(title: Copy.SettingsCopy.title)

                    skinSection
                    senseSection
                    voiceSection
                    promptSection
                    calendarSection
                    themeSection
                    nudgeSection
                    gardenSection
                    cloudLLMSection
                    cloudSection
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
            .sheet(isPresented: $showingCalendar) {
                WishCalendarView()
                    .environment(store)
                    .environment(\.theme, theme)
            }
        }
    }

    // MARK: 朗读声音 — pick which voice (tone) reads each language.

    @ViewBuilder private var voiceSection: some View {
        let langs = VoicePrefs.availableLanguages()
        if !langs.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("朗读声音")
                    .font(.system(size: 14)).foregroundStyle(theme.textMuted)
                Text("选择每种语言用哪个声音朗读。")
                    .font(.system(size: 12)).foregroundStyle(theme.textMuted)
                let _ = voiceRefresh   // re-read the current selection after a change
                ForEach(langs, id: \.code) { lang in
                    voiceRow(code: lang.code, name: lang.name)
                }
            }
        }
    }

    private func voiceRow(code: String, name: String) -> some View {
        let voices = VoicePrefs.voices(for: code)
        let selectedID = VoicePrefs.selectedIdentifier(for: code)
        let current = voices.first { $0.identifier == selectedID }
        return HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .medium)).foregroundStyle(theme.textPrimary)
                Text(current.map(VoicePrefs.label) ?? "系统默认")
                    .font(.system(size: 12)).foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            Spacer()
            // Preview the currently-chosen voice.
            Button {
                voicePreview.toggle(id: "prev-\(code)", text: previewText(code), language: code)
            } label: {
                Image(systemName: "speaker.wave.2.circle").font(.system(size: 22))
                    .foregroundStyle(theme.accentText)
            }.buttonStyle(.plain)
            Menu {
                Button("系统默认") { VoicePrefs.setIdentifier(nil, for: code); voiceRefresh += 1 }
                ForEach(voices, id: \.identifier) { v in
                    Button(VoicePrefs.label(for: v)) {
                        VoicePrefs.setIdentifier(v.identifier, for: code); voiceRefresh += 1
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .padding(8).background(theme.surfaceSoft, in: Circle())
            }
        }
        .padding(Spacing.md)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(theme.border, lineWidth: 1))
    }

    private func previewText(_ code: String) -> String {
        switch VoicePrefs.lang2(code) {
        case "fr": return "Bonjour, ceci est une voix."
        case "zh": return "你好，这是一个声音。"
        case "ja": return "こんにちは、これは声です。"
        case "ko": return "안녕하세요, 이것은 목소리입니다."
        case "es": return "Hola, esta es una voz."
        case "de": return "Hallo, das ist eine Stimme."
        case "it": return "Ciao, questa è una voce."
        default:   return "Hello, this is a voice."
        }
    }

    // MARK: 讲解风格 — see & edit the prompt templates behind the lessons.

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("讲解风格")
                .font(.system(size: 14)).foregroundStyle(theme.textMuted)
            Text("看看每种讲解用的提示词，也可以改成你喜欢的风格。")
                .font(.system(size: 12)).foregroundStyle(theme.textMuted)
            ForEach(PromptKind.allCases) { kind in
                NavigationLink { PromptEditorView(kind: kind) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).font(.system(size: 15, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Text(PromptTemplates.isCustom(kind) ? "已自定义" : "系统默认")
                                .font(.system(size: 12)).foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.textMuted)
                    }
                    .padding(Spacing.md)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 愿望日历 — a calendar-stack look-back at every wish caught this week.

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("愿望日历")
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)
            Button { showingCalendar = true } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.accent)
                        .frame(width: 36, height: 36)
                        .background(theme.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("看看这一周的愿望")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Text("按接住的那天，堆成七叠小卡片")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textMuted)
                }
                .padding(Spacing.md)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
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
                set: { v in
                    store.updateSettings { $0.nudgesEnabled = v }
                    if v { Nudger.shared.requestPermissionIfNeeded() }
                    else { Nudger.shared.cancelPending() }
                }
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

            if store.settings.nudgesEnabled {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Text("安静时段").font(.system(size: 14))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { store.settings.quietHoursStart },
                            set: { v in store.updateSettings { $0.quietHoursStart = v } }
                        )) {
                            ForEach(0..<24, id: \.self) { Text("\($0):00").tag($0) }
                        }
                        .labelsHidden()
                        Text("到").font(.system(size: 13)).foregroundStyle(theme.textMuted)
                        Picker("", selection: Binding(
                            get: { store.settings.quietHoursEnd },
                            set: { v in store.updateSettings { $0.quietHoursEnd = v } }
                        )) {
                            ForEach(0..<24, id: \.self) { Text("\($0):00").tag($0) }
                        }
                        .labelsHidden()
                    }
                    Stepper(value: Binding(
                        get: { store.settings.maxRemindersPerDay },
                        set: { v in store.updateSettings { $0.maxRemindersPerDay = v } }
                    ), in: 1...3) {
                        Text("一天最多 \(store.settings.maxRemindersPerDay) 次")
                            .font(.system(size: 14))
                            .foregroundStyle(theme.textPrimary)
                    }
                    Text("深夜永远不会打扰，这条规则改不了。")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textMuted)
                }
                .padding(Spacing.md)
                .background(theme.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
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

    // MARK: iCloud 同步 — the same gardens on every device with this Apple 账户.
    // The interactive toggle only exists in builds carrying the CloudKit
    // entitlement (CLOUDKIT_ENABLED, paid developer program). Until then the
    // section is a quiet, inert note — the feature is disabled by decision.

    // MARK: 高级 · 云端讲解 — point the study features at your own OpenAI-compatible endpoint.
    private var cloudLLMSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("高级 · 云端讲解")
                .font(.system(size: 14)).foregroundStyle(theme.textMuted)
            Text("填一个 OpenAI 兼容的地址（你自己的服务器，如家里跑 vLLM 的 H200），讲解、笔记、小课、译文会先用它，连不上时自动回到本机模型。原文会发到这个地址，请用 https。")
                .font(.system(size: 12)).lineSpacing(2).foregroundStyle(theme.textMuted)

            VStack(spacing: Spacing.sm) {
                cloudField(title: "Base URL", text: $cloudBase,
                           placeholder: "https://你的地址/v1", secure: false)
                cloudField(title: "API Key（可选）", text: $cloudKey,
                           placeholder: "sk-…", secure: true)
                cloudField(title: "模型（可选）", text: $cloudModel,
                           placeholder: "如 qwen2.5-72b-instruct", secure: false)
            }
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(theme.border, lineWidth: 1))

            HStack(spacing: Spacing.sm) {
                SoftButton(title: cloudTesting ? "测试中…" : "测试连接", variant: .ghost) {
                    saveCloud()
                    cloudTesting = true
                    cloudTestResult = nil
                    Task {
                        let ok = await CloudLLM.test()
                        await MainActor.run {
                            cloudTesting = false
                            cloudTestResult = ok
                        }
                    }
                }
                .disabled(cloudBase.trimmingCharacters(in: .whitespaces).isEmpty || cloudTesting)
                if let r = cloudTestResult {
                    Label(r ? "连接成功" : "连不上",
                          systemImage: r ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(r ? theme.accent : theme.textMuted)
                }
                Spacer()
            }
        }
        .onChange(of: cloudBase) { _, _ in saveCloud() }
        .onChange(of: cloudKey) { _, _ in saveCloud() }
        .onChange(of: cloudModel) { _, _ in saveCloud() }
    }

    private func cloudField(title: String, text: Binding<String>,
                            placeholder: String, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(theme.textPrimary)
        }
    }

    private func saveCloud() {
        CloudLLM.baseURL = cloudBase
        CloudLLM.apiKey = cloudKey
        CloudLLM.model = cloudModel
    }

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("iCloud 同步")
                .font(.system(size: 14))
                .foregroundStyle(theme.textMuted)
            #if CLOUDKIT_ENABLED
            Toggle(isOn: Binding(
                get: { store.cloudSyncOn },
                set: { store.setCloudSync($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.cloudSyncOn ? "在你的设备之间同步" : "只留在这台设备上")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.textPrimary)
                    Text("同一个 Apple 账户的 iPhone / iPad / Mac 共享愿望、痕迹、手帐和设置。走 iCloud 私人数据库，别人看不到。")
                        .font(.system(size: 12)).lineSpacing(2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .tint(theme.accent)
            .padding(Spacing.md)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(store.cloudSyncOn ? theme.accent : theme.border, lineWidth: 1))
            Text(store.cloudSyncActive
                 ? "已连接 iCloud · 回到应用时会带回其他设备的痕迹。"
                 : "开关在下次启动时生效。")
                .font(.system(size: 12))
                .foregroundStyle(theme.textMuted)
            #else
            HStack(spacing: Spacing.sm) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.textMuted)
                Text("暂未开通 — 需要 Apple 开发者计划的 iCloud 权限。开通后，同一个 Apple 账户的设备会共享愿望、痕迹、手帐和设置。")
                    .font(.system(size: 12)).lineSpacing(2)
                    .foregroundStyle(theme.textMuted)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            #endif
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
