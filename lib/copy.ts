// Centralized copy system. Warm, gentle, never shaming. Never todo-app language.

export const copy = {
  appTitle: "今天别消失",
  appTagline: "不用计划一整天。只要抓住一个小瞬间。",

  intro: {
    body: "把脑子里一闪而过的小愿望丢进来，它们会变成一颗颗种子。\n当你想做点什么，我帮你挑一个现在刚好合适的小动作。\n做了一点，也算——今天就留下一道痕迹。",
    cta: "开始吧",
  },

  home: {
    question: "今天想不想留下一个小痕迹？",
    subtitle: "不用计划一整天。\n只要抓住一个小瞬间。",
    primary: "现在别消失",
    traceHeading: "今日痕迹",
    traceEmpty: "还没有，但可以很小。",
    seedsHeading: "最近的小愿望",
    seedsEmpty: "还没有愿望。冒出来一个，就丢进来。",
  },

  add: {
    prompt: "把刚刚冒出来的小愿望丢进来……",
    inputLabel: "把刚刚冒出来的小愿望写下来",
    placeholder: "我想记几个法语单词。\n我想找个地方坐一会。\n我想去市中心走走。\n我想亲手看懂一点代码。",
    caught: "我帮你接住了这个愿望：",
    minLabel: "最低完成：",
    fitLabel: "适合：",
    save: "保存这个愿望",
    edit: "改一改",
    again: "再丢一个",
  },

  garden: {
    title: "愿望花园",
    subtitle: "这些不是任务。\n它们只是还在等一个合适的时刻。",
    empty: "花园还空着。\n冒出来一个小愿望，就把它种进来。",
    sampleNote: "这些是几个示例愿望，先帮你感受一下。\n随时可以改成自己的，或者轻轻收起来。",
    sampleNoteDismiss: "知道了",
  },

  seedDetail: {
    back: "← 回到花园",
    titleLabel: "这个愿望",
    minLabel: "最低完成",
    save: "保存修改",
    saved: "已经记下了。",
    sleep: "让它先睡一会",
    wake: "唤醒它",
    archive: "轻轻收起来",
    restore: "放回花园",
    notFound: "这个愿望好像已经不在花园里了。",
    statusActive: "在等一个时机",
    statusSleeping: "正在睡着",
    statusArchived: "已经收起来了",
  },

  now: {
    moodQuestion: "你现在大概是什么状态？",
    energyQuestion: "现在还有多少力气？",
    freeQuestion: "大概有多少空？",
    placeQuestion: "你现在在哪？（可跳过）",
    weatherLabel: "外面天气不错",
    findButton: "看看现在适合做什么",
    reasonLabel: "为什么现在适合：",
    minLabel: "最低目标：",
    start: "开始一点点",
    swap: "换一个",
    later: "今天先这样",
    recordRest: "把「我今天选择了停下」记成一笔",
    noneTitle: "现在不用做什么。",
    noneBody: "愿望都还在，等下一个契机。",
  },

  completion: {
    prompt: "做到了吗？",
    done: "完成了",
    partial: "做了一点",
    skipped: "没做，但我知道了",
    skippedMsg: "没关系。愿望还在，等下一个契机。",
  },

  traces: {
    title: "今日痕迹",
    subtitle: "不是成就列表。\n只是你曾经真实在场的瞬间。",
    empty: "还没有痕迹。\n今天做了一点点真实的事，就会出现在这里。",
    edit: "改成自己的话",
    editSave: "就这样",
    editPlaceholder: "用你自己的话，写下今天没有消失的理由……",
    export: "把你的痕迹存下来",
    exported: "已经复制下来了",
    exportFailed: "复制没成功，可以长按上面的文字手动复制",
    deleteAria: "擦掉这一条痕迹",
    deleteTitle: "擦掉这一条痕迹？",
    deleteBody: "它会从今日痕迹里消失。这一步无法撤回。",
    deleteYes: "擦掉",
    deleteNo: "留着",
  },

  settings: {
    title: "设置",
    themeLabel: "外观",
    aiLabel: "AI 模式",
    quietLabel: "安静时段",
    quietHelp: "这段时间它完全不打扰你。",
    quietFrom: "从",
    quietTo: "到",
    quietNow: "现在正处在安静时段，它不会主动打扰你。",
    quietNotNow: "现在不在安静时段。",
    maxRemindersLabel: "每天最多递几次契机",
    resetLabel: "清空本地数据",
    resetConfirmTitle: "清空所有愿望和痕迹？",
    resetConfirm: "这会清空你保存的所有愿望和痕迹，无法撤回。",
    resetConfirmYes: "确定清空",
    resetConfirmNo: "先不要",
    privacy: "这个 app 不应该吵你。\n它只应该在合适的时候轻轻递一个契机。",
  },

  lateNight: {
    title: "现在已经很晚了。",
    body: "今天不用补救人生。\n你不需要把整个晚上抢回来。\n\n选一个止损动作：\n喝水、洗漱、关机、上床。\n\n完成一个，今天就没有完全消失。",
    themeOffer: "要不要把灯光调暗一点，换上睡前的样子？",
    themeAccept: "换上睡前的灯光",
    themeDismiss: "不用了",
  },

  tracePrefix: "今天没有消失，因为",
} as const;

// Forbidden vocabulary — used by tests/lint to keep the tone safe.
// Note: the bare word 任务 is NOT banned — the app intentionally says
// "这些不是任务" to contrast itself with todo apps. What we forbid is todo
// *framing*, *mechanics*, and *shaming* actually leaking into our own voice.
export const forbiddenWords = [
  // todo framing / mechanics
  "待办",
  "任务列表",
  "完成任务",
  "todo",
  "to-do",
  "deadline",
  "overdue",
  "高优先级",
  "优先级",
  "完成率",
  "streak",
  "打卡",
  // shaming
  "失败",
  "you must",
  "you failed",
];
