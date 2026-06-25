# Product Philosophy — 《今天别消失》

> Seed 是种子。Context 是天气和土壤。Opportunity 是发芽的时机。Trace 是今天留下的年轮。AI 是帮我看见时机的风。

This is an AI **life-anchor** app, not a productivity tool. It exists to catch a small, soft wish and hand it back at the right moment, so that — even on an autopilot day — *today did not completely disappear.*

## Non-goals (enforced in code & copy)
- No tasks, deadlines, overdue, priorities, completion %, streaks, punishment.
- No shame. Partial counts. Skipping is fine — "愿望还在，等下一个契机".
- AI never commands, diagnoses, says "I love you", or pushes all-night work. It says: "现在好像刚好适合做一点点。"

## The one question
Not "how productive were you?" but "今天有没有一个瞬间，你是真的在场的？"

## How the philosophy shows up technically
- **Anchors → categories** (body / creation / connection / exploration / recovery / learning / aesthetic) drive mood-aware recommendation.
- **Minimum action** on every seed keeps the bar tiny; the parser is forbidden from producing homework.
- **Late-night protection** is a hard safety gate, not a suggestion.
- **Traces** are warm sentences, never a scoreboard.

## Tone rules
- One primary action per screen. Large whitespace. Soft motion. Warm but not cheesy.
- Copy lives in `lib/copy.ts`; `forbiddenWords` documents the vocabulary we refuse.
