import Foundation
import EventKit

enum ReminderBridge {
    static let store = EKEventStore()

    static func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(to: .reminder)
        } catch {
            return false
        }
    }

    static func add(title: String, due: Date?) -> Bool {
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders
        if let due {
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        do {
            try store.save(reminder, commit: true)
            return true
        } catch {
            return false
        }
    }
}

