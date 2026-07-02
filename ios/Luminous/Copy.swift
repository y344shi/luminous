//
//  Copy.swift
//  Luminous
//
//  Centralized copy. Warm, gentle, never shaming. Never todo-app language.
//  Ported from lib/copy.ts.
//

import Foundation

enum Copy {
    static let appTitle = "今天别消失"
    static let appTagline = "不用计划一整天。只要抓住一个小瞬间。"

    enum Intro {
        static let body = "把脑子里一闪而过的小愿望丢进来，它们会变成一颗颗种子。\n当你想做点什么，我帮你挑一个现在刚好合适的小动作。\n做了一点，也算——今天就留下一道痕迹。"
        static let cta = "开始吧"
    }

    enum Home {
        static let question = "今天想不想留下一个小痕迹？"
        static let subtitle = "不用计划一整天。\n只要抓住一个小瞬间。"
        static let primary = "现在别消失"
        static let bubblesLead = "也许现在，可以做一点这些："
        static let bubblesEmpty = "现在不用做什么，先这样也好。"
        static let traceHeading = "今日痕迹"
        static let traceEmpty = "还没有，但可以很小。"
        static let seedsHeading = "最近的小愿望"
        static let seedsEmpty = "还没有愿望。冒出来一个，就丢进来。"
        static let addSeed = "丢一个新愿望"
    }

    enum Add {
        static let prompt = "把刚刚冒出来的小愿望丢进来……"
        static let inputLabel = "把刚刚冒出来的小愿望写下来"
        static let placeholder = "我想记几个法语单词。\n我想找个地方坐一会。\n我想去市中心走走。\n我想亲手看懂一点代码。"
        static let caught = "我帮你接住了这个愿望："
        static let minLabel = "最低完成："
        static let fitLabel = "适合："
        static let save = "保存这个愿望"
        static let edit = "改一改"
        static let again = "再丢一个"
        static let catchIt = "接住它"
    }

    enum Garden {
        static let title = "愿望花园"
        static let subtitle = "这些不是任务。\n它们只是还在等一个合适的时刻。"
        static let empty = "花园还空着。\n冒出来一个小愿望，就把它种进来。"
        static let sampleNote = "这些是几个示例愿望，先帮你感受一下。\n随时可以改成自己的，或者轻轻收起来。"
        static let sampleNoteDismiss = "知道了"
    }

    enum SeedDetail {
        static let back = "← 回到花园"
        static let titleLabel = "这个愿望"
        static let minLabel = "最低完成"
        static let save = "保存修改"
        static let saved = "已经记下了。"
        static let sleep = "让它先睡一会"
        static let wake = "唤醒它"
        static let archive = "轻轻收起来"
        static let restore = "放回花园"
        static let notFound = "这个愿望好像已经不在花园里了。"
        static let statusActive = "在等一个时机"
        static let statusSleeping = "正在睡着"
        static let statusArchived = "已经收起来了"
    }

    enum Now {
        static let moodQuestion = "你现在大概是什么状态？"
        static let energyQuestion = "现在还有多少力气？"
        static let freeQuestion = "大概有多少空？"
        static let placeQuestion = "你现在在哪？（可跳过）"
        static let weatherLabel = "外面天气不错"
        static let findButton = "看看现在适合做什么"
        static let reasonLabel = "为什么现在适合："
        static let minLabel = "最低目标："
        static let start = "开始一点点"
        static let swap = "换一个"
        static let later = "今天先这样"
        static let recordRest = "把「我今天选择了停下」记成一笔"
        static let noneTitle = "现在不用做什么。"
        static let noneBody = "愿望都还在，等下一个契机。"
        static let orAlso = "或者，现在也可以："
        static let backToToday = "回到今天"
        static let seeTraces = "看看今日痕迹"
        static let plantNew = "去种一个新愿望"
    }

    enum Completion {
        static let prompt = "做到了吗？"
        static let done = "完成了"
        static let partial = "做了一点"
        static let skipped = "没做，但我知道了"
        static let skippedMsg = "没关系。愿望还在，等下一个契机。"
    }

    enum Traces {
        static let title = "今日痕迹"
        static let subtitle = "不是成就列表。\n只是你曾经真实在场的瞬间。"
        static let empty = "还没有痕迹。\n今天做了一点点真实的事，就会出现在这里。"
        static let edit = "改成自己的话"
        static let editSave = "就这样"
        static let editPlaceholder = "用你自己的话，写下今天没有消失的理由……"
        static let export = "把你的痕迹存下来"
        static let exported = "已经复制下来了"
        static let deleteTitle = "擦掉这一条痕迹？"
        static let deleteBody = "它会从今日痕迹里消失。这一步无法撤回。"
        static let deleteYes = "擦掉"
        static let deleteNo = "留着"
    }

    enum SettingsCopy {
        static let title = "设置"
        static let themeLabel = "外观"
        static let nudgeLabel = "轻轻提醒"
        static let resetLabel = "清空本地数据"
        static let resetConfirmTitle = "清空所有愿望和痕迹？"
        static let resetConfirm = "这会清空你保存的所有愿望和痕迹，无法撤回。"
        static let resetConfirmYes = "确定清空"
        static let resetConfirmNo = "先不要"
        static let privacy = "这个 app 不应该吵你。\n它只应该在合适的时候轻轻递一个契机。"
    }

    enum LateNight {
        static let title = "现在已经很晚了。"
        static let body = "今天不用补救人生。\n你不需要把整个晚上抢回来。\n\n选一个止损动作：\n喝水、洗漱、关机、上床。\n\n完成一个，今天就没有完全消失。"
        static let themeOffer = "要不要把灯光调暗一点，换上睡前的样子？"
        static let themeAccept = "换上睡前的灯光"
        static let themeDismiss = "不用了"
    }

    static let tracePrefix = "今天没有消失，因为"

    // Tab labels (port of BottomNav)
    enum Tab {
        static let today = "今天"
        static let seeds = "愿望"
        static let traces = "痕迹"
        static let settings = "设置"
    }
}

// MARK: - Category & label metadata (port of lib/categoryMeta.ts)

struct CategoryMeta {
    let label: String
    let emoji: String
}

enum Meta {
    static let category: [SeedCategory: CategoryMeta] = [
        .body: CategoryMeta(label: "身体", emoji: "🍵"),
        .creation: CategoryMeta(label: "创造", emoji: "✏️"),
        .connection: CategoryMeta(label: "连接", emoji: "🤍"),
        .exploration: CategoryMeta(label: "探索", emoji: "🚶"),
        .recovery: CategoryMeta(label: "恢复", emoji: "🫧"),
        .learning: CategoryMeta(label: "学习", emoji: "📓"),
        .aesthetic: CategoryMeta(label: "审美", emoji: "🌿"),
    ]

    static let energyLabel: [Energy: String] = [
        .low: "低能量",
        .medium: "中等",
        .high: "需要点劲",
    ]

    static func durationLabel(_ min: Int) -> String {
        if min <= 5 { return "几分钟" }
        if min <= 15 { return "十几分钟" }
        if min <= 30 { return "半小时内" }
        if min <= 60 { return "一小时内" }
        return "可长可短"
    }
}

// MARK: - The vocabulary we refuse (port of packages/core copy.ts forbiddenWords)

/// Words this app must never say — todo-app mechanics and shame. Every piece of
/// model-generated copy is filtered through this before it reaches the user.
enum ForbiddenWords {
    static let all: [String] = [
        // todo framing / mechanics
        "待办", "任务列表", "完成任务", "todo", "to-do", "deadline", "overdue",
        "高优先级", "优先级", "完成率", "streak", "打卡",
        // shaming
        "失败", "you must", "you failed",
    ]

    /// True when the text is clean enough to show.
    static func passes(_ text: String) -> Bool {
        let lower = text.lowercased()
        return !all.contains { lower.contains($0.lowercased()) }
    }
}

// MARK: - Picker options (port of components/context/Pickers.tsx)

struct PickerOption<T> {
    let value: T
    let label: String
}

enum Pickers {
    static let mood: [PickerOption<Mood>] = [
        .init(value: .empty, label: "有点空"),
        .init(value: .tired, label: "累"),
        .init(value: .anxious, label: "焦虑"),
        .init(value: .okay, label: "还行"),
        .init(value: .alive, label: "有点想活过来"),
        .init(value: .avoidant, label: "想逃避"),
        .init(value: .wantLove, label: "想被爱"),
        .init(value: .lonely, label: "有点孤单"),
        .init(value: .unknown, label: "我也不知道"),
    ]

    static let energy: [PickerOption<Energy>] = [
        .init(value: .low, label: "低"),
        .init(value: .medium, label: "中"),
        .init(value: .high, label: "高"),
    ]

    static let free: [PickerOption<Int?>] = [
        .init(value: 5, label: "5 分钟"),
        .init(value: 15, label: "15 分钟"),
        .init(value: 30, label: "30 分钟"),
        .init(value: 90, label: "1 小时以上"),
        .init(value: nil, label: "不知道"),
    ]

    static let location: [PickerOption<LocationType>] = [
        .init(value: .home, label: "在家"),
        .init(value: .computer, label: "电脑前"),
        .init(value: .outdoor, label: "在外面"),
        .init(value: .downtown, label: "市中心"),
        .init(value: .transit, label: "路上"),
    ]
}
