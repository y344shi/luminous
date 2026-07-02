//
//  Nudge.swift
//  Luminous — the app may reach out, at most barely
//
//  The dormant Settings fields (nudgesEnabled / quietHours / maxRemindersPerDay)
//  finally do what they promise. Everything outward passes NudgeGate — pure,
//  tested, and strict: nudges are OFF by default, never in quiet hours, never
//  late at night, never more than the daily cap, and only one pending at a
//  time. One gentle line, no badge, no sound of alarm — a hand on the shoulder,
//  not a bell.
//
//  Honest limitation (logged in OVERNIGHT-SESSION.md): sensing is foreground-
//  only, so the trigger is "you left the app while a wish was ripe" — we
//  schedule ONE soft reminder for a fitting later hour, and cancel it the
//  moment you come back. True arrive-at-a-place nudges need Always-location.
//

import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

// MARK: - The gate (pure, tested)

enum NudgeGate {

    struct Input {
        var nudgesEnabled: Bool
        var quietStart: Int      // e.g. 23
        var quietEnd: Int        // e.g. 8
        var maxPerDay: Int
        var sentToday: Int
        var hour: Int            // the hour the nudge would ARRIVE
        init(nudgesEnabled: Bool, quietStart: Int, quietEnd: Int,
             maxPerDay: Int, sentToday: Int, hour: Int) {
            self.nudgesEnabled = nudgesEnabled
            self.quietStart = quietStart; self.quietEnd = quietEnd
            self.maxPerDay = maxPerDay; self.sentToday = sentToday
            self.hour = hour
        }
    }

    /// Quiet hours wrap midnight (23 → 8). Equal start/end = never quiet.
    static func inQuietHours(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        return start < end
            ? (hour >= start && hour < end)
            : (hour >= start || hour < end)
    }

    static func allows(_ i: Input) -> Bool {
        guard i.nudgesEnabled else { return false }
        guard i.sentToday < i.maxPerDay else { return false }
        guard !inQuietHours(hour: i.hour, start: i.quietStart, end: i.quietEnd) else { return false }
        guard !TimeOfDay.isLateNight(hour: i.hour) else { return false }   // absolute
        return true
    }
}

// MARK: - The scheduler (app targets only in practice; framework-guarded)

#if canImport(UserNotifications)
@MainActor
final class Nudger {

    static let shared = Nudger()
    private static let pendingId = "tdd.nudge.pending"
    private let defaults = UserDefaults.standard

    private var todayKey: String { "tdd.nudges." + DomainUtil.localDateKey() }
    var sentToday: Int { defaults.integer(forKey: todayKey) }

    /// Ask for permission only at the moment the user turns 提醒 on.
    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert]) { _, _ in }
    }

    /// Schedule the single soft reminder, if the gate allows its arrival hour.
    /// Replaces any previous pending one — never a queue.
    func schedule(title: String, body: String, at date: Date, settings: Settings) {
        let hour = Calendar.current.component(.hour, from: date)
        let input = NudgeGate.Input(
            nudgesEnabled: settings.nudgesEnabled,
            quietStart: settings.quietHoursStart,
            quietEnd: settings.quietHoursEnd,
            maxPerDay: settings.maxRemindersPerDay,
            sentToday: sentToday,
            hour: hour)
        guard NudgeGate.allows(input), date > Date() else { return }
        guard ForbiddenWords.passes(title + body) else { return }

        cancelPending()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil                          // a hand, not a bell
        let secs = max(60, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secs, repeats: false)
        let req = UNNotificationRequest(identifier: Self.pendingId,
                                        content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req) { [weak self] err in
            guard err == nil else { return }
            Task { @MainActor in
                guard let self else { return }
                self.defaults.set(self.sentToday + 1, forKey: self.todayKey)
            }
        }
    }

    /// Coming back to the app dissolves the pending nudge — you're already here.
    func cancelPending() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.pendingId])
    }
}
#endif
