import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    static func schedule(for item: MemoryItemModel) {
        guard let dueDate = item.dueDate else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        if components.hour == 0 && components.minute == 0 {
            components.hour = 9
        }
        guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Aftermind Reminder"
        content.body = item.title
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

