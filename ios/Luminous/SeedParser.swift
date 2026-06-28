//
//  SeedParser.swift
//  Luminous
//
//  Mock NL parser (text → SeedDraft) + the first-run mock garden + trace generator.
//  Ported from lib/{seedParser,mockSeeds,traceGenerator}.ts. The parser is the
//  swap point for a real on-device model later.
//

import Foundation

struct SeedTemplate {
    var title: String
    var rawText: String
    var description: String?
    var categories: [SeedCategory]
    var minimumAction: String
    var estimatedDurationMin: Int
    var energyRequired: Energy
    var locationType: LocationType
    var preferredTimes: [SemanticTime]
    var triggerConditions: [String]
}

typealias SeedDraft = SeedTemplate

// MARK: - Mock garden (port of lib/mockSeeds.ts)

enum MockGarden {
    static let templates: [SeedTemplate] = [
        SeedTemplate(title: "记 3 个法语单词", rawText: "我想记几个法语单词",
                     categories: [.learning], minimumAction: "记住 3 个法语词，不要求复习更多",
                     estimatedDurationMin: 5, energyRequired: .low, locationType: .anywhere,
                     preferredTimes: [.lunch, .evening, .transit],
                     triggerConditions: ["short_free_time", "low_energy_ok"]),
        SeedTemplate(title: "坐一会野外", rawText: "我想找个天气好的时候坐一会野外",
                     categories: [.recovery, .exploration], minimumAction: "在户外坐 10 分钟，不刷手机",
                     estimatedDurationMin: 15, energyRequired: .low, locationType: .outdoor,
                     preferredTimes: [.afternoon, .afterWork, .weekend],
                     triggerConditions: ["weather_good", "near_outdoor", "free_time_15min"]),
        SeedTemplate(title: "去市中心走走", rawText: "我想去市中心走走，喝杯咖啡，拍点照片",
                     categories: [.exploration, .aesthetic], minimumAction: "到一个街区走 20 分钟，拍一张照片",
                     estimatedDurationMin: 90, energyRequired: .medium, locationType: .downtown,
                     preferredTimes: [.weekend, .afterWork],
                     triggerConditions: ["free_time_90min", "energy_medium", "not_late_night"]),
        SeedTemplate(title: "吃一顿热饭", rawText: "我想别再糊弄吃饭，给自己吃一顿热的",
                     categories: [.body], minimumAction: "吃一顿有蛋白质的热饭",
                     estimatedDurationMin: 20, energyRequired: .low, locationType: .home,
                     preferredTimes: [.evening],
                     triggerConditions: ["evening", "low_energy_ok"]),
        SeedTemplate(title: "亲手理解一个模块", rawText: "我不想全交给 Claude，我想亲手理解一个芯片模块",
                     categories: [.creation, .learning], minimumAction: "看懂 20 行代码，写 5 行笔记",
                     estimatedDurationMin: 30, energyRequired: .medium, locationType: .computer,
                     preferredTimes: [.evening, .weekend],
                     triggerConditions: ["at_computer", "energy_medium", "not_late_night"]),
        SeedTemplate(title: "夺回一点方向盘", rawText: "我不想全交给 Claude 做，自己没有长进",
                     categories: [.creation, .learning], minimumAction: "打开 Claude 写的代码，标出 10 行我真的懂的地方",
                     estimatedDurationMin: 20, energyRequired: .medium, locationType: .computer,
                     preferredTimes: [.evening, .weekend],
                     triggerConditions: ["at_computer", "avoidant_mood"]),
        SeedTemplate(title: "给一个人发一句真话", rawText: "我想被爱，也想爱别人",
                     categories: [.connection], minimumAction: "给一个不会消耗你的人发一句真诚的话",
                     estimatedDurationMin: 5, energyRequired: .low, locationType: .anywhere,
                     preferredTimes: [.evening, .weekend],
                     triggerConditions: ["lonely", "want_love", "short_free_time"]),
        SeedTemplate(title: "深夜止损", rawText: "现在已经很晚了，我不想再让今天消失",
                     categories: [.body, .recovery], minimumAction: "喝水、洗漱、关机、上床，完成一个就算",
                     estimatedDurationMin: 8, energyRequired: .low, locationType: .home,
                     preferredTimes: [.lateNight],
                     triggerConditions: ["late_night", "rescue_mode"]),
    ]

    static func materialize(_ t: SeedTemplate) -> Seed {
        let ts = DomainUtil.nowIso()
        return Seed(
            id: DomainUtil.uid("seed"),
            rawText: t.rawText, title: t.title, description: t.description,
            categories: t.categories, minimumAction: t.minimumAction,
            estimatedDurationMin: t.estimatedDurationMin, energyRequired: t.energyRequired,
            locationType: t.locationType, preferredTimes: t.preferredTimes,
            triggerConditions: t.triggerConditions, status: .active,
            createdAt: ts, updatedAt: ts
        )
    }

    static func seed() -> [Seed] { templates.map(materialize) }
}

// MARK: - Mock parser (port of lib/seedParser.ts)

enum SeedParser {
    private struct Rule {
        let pattern: String
        let categories: [SeedCategory]
        var location: LocationType?
        var energy: Energy?
        var durationMin: Int?
        var times: [SemanticTime]?
        var triggers: [String]?
        var minimumAction: String?
        var title: String?
    }

    // Keyword heuristics. Order matters: earlier rules win their fields.
    private static let rules: [Rule] = [
        Rule(pattern: "法语|单词|外语|背词|french|word", categories: [.learning],
             location: .anywhere, energy: .low, durationMin: 5,
             times: [.lunch, .evening, .transit], triggers: ["short_free_time", "low_energy_ok"],
             minimumAction: "记住 3 个词，不要求复习更多", title: "记几个词"),
        Rule(pattern: "野外|草地|公园|户外|自然|河边|绿地", categories: [.recovery, .exploration],
             location: .outdoor, energy: .low, durationMin: 15,
             times: [.afternoon, .afterWork, .weekend], triggers: ["weather_good", "near_outdoor", "free_time_15min"],
             minimumAction: "在户外坐 10 分钟，不刷手机", title: "坐一会野外"),
        Rule(pattern: "市中心|街区|逛|downtown|城市|街上|散步去", categories: [.exploration, .aesthetic],
             location: .downtown, energy: .medium, durationMin: 90,
             times: [.weekend, .afterWork], triggers: ["free_time_90min", "energy_medium", "not_late_night"],
             minimumAction: "到一个街区走 20 分钟，拍一张照片", title: "去走走"),
        Rule(pattern: "热饭|吃饭|做饭|做菜|煮|吃一顿|蛋白质|好好吃", categories: [.body],
             location: .home, energy: .low, durationMin: 20,
             times: [.evening], triggers: ["evening", "low_energy_ok"],
             minimumAction: "给自己吃一顿有蛋白质的热饭", title: "吃一顿热饭"),
        Rule(pattern: "claude|代码|模块|芯片|testbench|bug|看懂", categories: [.creation, .learning],
             location: .computer, energy: .medium, durationMin: 25,
             times: [.evening, .weekend], triggers: ["at_computer", "not_late_night"],
             minimumAction: "看懂 20 行代码，写 5 行笔记", title: "亲手理解一点代码"),
        Rule(pattern: "朋友|发消息|联系|表达|感谢|温柔|被爱|爱别人|消息|回信", categories: [.connection],
             location: .anywhere, energy: .low, durationMin: 5,
             times: [.evening, .weekend], triggers: ["short_free_time"],
             minimumAction: "给一个不会消耗你的人发一句真诚的话", title: "发一句真话"),
        Rule(pattern: "拍照|拍一张|光|颜色|树|美|风景|photo|记录一个", categories: [.aesthetic],
             location: .anywhere, energy: .low, durationMin: 5,
             times: [.afternoon, .afterWork, .weekend], triggers: ["short_free_time"],
             minimumAction: "拍一张让你停下来的光或颜色", title: "留住一个画面"),
        Rule(pattern: "睡|洗漱|关机|止损|喝水|休息|太晚|别熬", categories: [.body, .recovery],
             location: .home, energy: .low, durationMin: 8,
             times: [.lateNight, .evening], triggers: ["late_night", "rescue_mode"],
             minimumAction: "喝水、洗漱、关机、上床，完成一个就算", title: "今天先这样"),
    ]

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func titleFromText(_ raw: String) -> String {
        let cleaned = raw.replacingOccurrences(
            of: "^我?\\s*(想|要|希望|得|该)\\s*",
            with: "", options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let head = cleaned.components(separatedBy: CharacterSet(charactersIn: "，。,.\n")).first ?? cleaned
        let pick = head.isEmpty ? (cleaned.isEmpty ? "一个小愿望" : cleaned) : head
        return String(pick.prefix(16))
    }

    /// Turn a soft sentence into a small, low-friction Seed draft.
    static func parse(_ raw: String) -> SeedDraft {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        var categories: [SeedCategory] = []
        var location: LocationType = .anywhere
        var energy: Energy = .low
        var durationMin = 10
        var times: [SemanticTime] = [.evening]
        var triggers: [String] = ["short_free_time"]
        var minimumAction = ""
        var title = ""

        for rule in rules where matches(rule.pattern, text) {
            for c in rule.categories where !categories.contains(c) { categories.append(c) }
            if let l = rule.location { location = l }
            if let e = rule.energy { energy = e }
            if let d = rule.durationMin { durationMin = d }
            if let t = rule.times { times = t }
            if let tr = rule.triggers { triggers = tr }
            if let m = rule.minimumAction, minimumAction.isEmpty { minimumAction = m }
            if let ti = rule.title, title.isEmpty { title = ti }
        }

        if categories.isEmpty {
            categories = [.recovery]
            if minimumAction.isEmpty { minimumAction = "做最小的一步，做到一点也算" }
        }

        return SeedDraft(
            title: title.isEmpty ? titleFromText(text) : title,
            rawText: text,
            description: text.isEmpty ? nil : text,
            categories: categories,
            minimumAction: minimumAction.isEmpty ? "做最小的一步，做到一点也算" : minimumAction,
            estimatedDurationMin: durationMin,
            energyRequired: energy,
            locationType: location,
            preferredTimes: times,
            triggerConditions: triggers
        )
    }

    /// Promote a draft into a full persisted Seed.
    static func draftToSeed(_ draft: SeedDraft) -> Seed {
        let ts = DomainUtil.nowIso()
        return Seed(
            id: DomainUtil.uid("seed"),
            rawText: draft.rawText, title: draft.title, description: draft.description,
            categories: draft.categories, minimumAction: draft.minimumAction,
            estimatedDurationMin: draft.estimatedDurationMin, energyRequired: draft.energyRequired,
            locationType: draft.locationType, preferredTimes: draft.preferredTimes,
            triggerConditions: draft.triggerConditions, status: .active,
            createdAt: ts, updatedAt: ts
        )
    }
}

// MARK: - Trace generator (port of lib/traceGenerator.ts)

enum CompletionKind: String {
    case completed, partial, skipped
}

enum TraceGenerator {
    private static let completedReasons: [SeedCategory: String] = [
        .body: "你照顾了一下自己的身体",
        .creation: "你亲手做出了一点点东西",
        .connection: "你和一个人之间多了一点真实的连接",
        .exploration: "你让自己去了一个地方",
        .recovery: "你给自己留了一点喘息",
        .learning: "你让脑子里多了一点新的东西",
        .aesthetic: "你停下来，看见了一点美",
    ]

    private static let partialLines = [
        "你做了一点点，也算",
        "你没有完全放弃这个愿望",
        "你至少朝那个愿望靠近了一点",
    ]

    static func generateText(_ seed: Seed?, _ kind: CompletionKind) -> String {
        let prefix = Copy.tracePrefix
        switch kind {
        case .skipped:
            return Copy.Completion.skippedMsg
        case .partial:
            let idx = seed != nil ? seed!.id.count % partialLines.count : 0
            return "\(prefix)\(partialLines[idx])。"
        case .completed:
            if let seed = seed, let cat = seed.categories.first {
                let reason = completedReasons[cat] ?? "你朝「\(seed.title)」靠近了一点"
                return "\(prefix)\(reason)。"
            }
            return "\(prefix)你留下了一个真实的瞬间。"
        }
    }

    /// Choosing to stop is itself a real act.
    static func buildRestTrace(opportunityId: String? = nil, date: Date = Date()) -> DailyTrace {
        DailyTrace(
            id: DomainUtil.uid("trace"),
            date: DomainUtil.localDateKey(date),
            seedId: nil, opportunityId: opportunityId,
            text: "\(Copy.tracePrefix)你及时停下来了。",
            category: .recovery, partial: false, createdAt: DomainUtil.nowIso()
        )
    }

    static func buildTrace(_ seed: Seed?, _ kind: CompletionKind, opportunityId: String? = nil, date: Date = Date()) -> DailyTrace {
        DailyTrace(
            id: DomainUtil.uid("trace"),
            date: DomainUtil.localDateKey(date),
            seedId: seed?.id, opportunityId: opportunityId,
            text: generateText(seed, kind),
            category: seed?.categories.first,
            partial: kind == .partial,
            createdAt: DomainUtil.nowIso()
        )
    }
}
