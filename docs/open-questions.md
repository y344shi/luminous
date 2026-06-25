# Open Questions

For the morning review. Unresolved product/UX/tech choices.

1. **Auto-theme at late night?** Should the app auto-switch (or offer) `soft_ritual` when `isLateNight`? Leaning yes-but-offer, not force.
2. **Location & weather input.** How should the user supply location hint / good-weather? A one-tap "我在外面 / 天气不错" chip on the Now screen vs. a separate picker. Geolocation API later, but only coarse.
3. **Device context.** Now flow currently assumes `isAtComputer: true`. Detect via UA/viewport? Or ask once?
4. **Seed lifecycle.** Completed seeds go to `sleeping` so they can resurface. Should there be a real "done forever" vs "recurring wish" distinction without it feeling like task management?
5. **How much serendipity?** 5% weight — does the variety feel alive or random? Needs felt testing.
6. **Notifications.** What's the gentlest possible nudge that still helps someone on autopilot, without becoming a todo-app ping? Quiet hours + max/day are modeled but not yet enforced.
7. **Trace editing.** Should the user be able to write their own trace sentence (not just accept the generated one)?
8. **Real AI parser.** When enabled, where does it run (edge route) and how do we keep keys server-side + send only coarse text?
