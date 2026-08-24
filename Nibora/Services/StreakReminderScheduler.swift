//
//  StreakReminderScheduler.swift
//  Nibora
//

import Foundation
import UserNotifications

/// Schedules (or clears) a single local notification reminding you to
/// write today — always under the same identifier, so calling refresh()
/// again simply replaces whatever's pending rather than needing an
/// explicit cancel-then-add.
enum StreakReminderScheduler {
    private static let identifier = "streakReminder"

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Call whenever the reminder might need to change: preferences
    /// toggled/retimed, today's entry got created, or the day rolled over.
    static func refresh(preferences: StreakReminderPreferences, hasEntryForToday: Bool) {
        guard preferences.isEnabled, !hasEntryForToday else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let calendar = Calendar.current
        let now = Date()
        var fireDate = calendar.date(bySettingHour: preferences.reminderHour, minute: preferences.reminderMinute, second: 0, of: now) ?? now
        if fireDate <= now {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = "Nibora"
        content.body = "You haven't written today yet."
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
