import Foundation
import UserNotifications

enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    static func schedule(for item: MemoryItemModel) {
        guard let dueDate = item.dueDate else { return }
        let content = UNMutableNotificationContent()
        content.title = "Aftermind Reminder"
        content.body = item.title
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

