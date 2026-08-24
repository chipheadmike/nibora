//
//  StreakReminderPreferences.swift
//  Nibora
//

import Foundation

/// A quiet, local-only reminder if you haven't written by a chosen time —
/// no account or server involved, scheduled via UserNotifications.
@Observable
final class StreakReminderPreferences {
    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled) }
    }
    var reminderHour: Int {
        didSet { UserDefaults.standard.set(reminderHour, forKey: Keys.hour) }
    }
    var reminderMinute: Int {
        didSet { UserDefaults.standard.set(reminderMinute, forKey: Keys.minute) }
    }

    private enum Keys {
        static let isEnabled = "streakReminderPreferences.isEnabled"
        static let hour = "streakReminderPreferences.hour"
        static let minute = "streakReminderPreferences.minute"
    }

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        reminderHour = (UserDefaults.standard.object(forKey: Keys.hour) as? Int) ?? 20
        reminderMinute = (UserDefaults.standard.object(forKey: Keys.minute) as? Int) ?? 0
    }

    /// A bindable Date for a DatePicker(.hourAndMinute) — only the
    /// hour/minute components are meaningful; the date part is discarded on
    /// write since this represents a daily time-of-day, not a moment.
    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? reminderHour
            reminderMinute = components.minute ?? reminderMinute
        }
    }
}
