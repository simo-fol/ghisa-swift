import UIKit
import UserNotifications

/// iOS services: folders, notifications for the rest timer, screen, haptics.
enum Platform {
    private static let restId = "rest-timer"

    /// Folder for the working copy of the Excel file (visible in Files › On my iPhone).
    static let documentsDirectory = folder(.documentDirectory)

    /// Folder for the app's own state.
    static let stateDirectory = folder(.applicationSupportDirectory)

    private static func folder(_ kind: FileManager.SearchPathDirectory) -> URL {
        let url = FileManager.default.urls(for: kind, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func keepScreenOn(_ on: Bool) { UIApplication.shared.isIdleTimerDisabled = on }

    static func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = ForegroundPresenter.shared
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedules the "rest is over" alert, replacing any previous one.
    static func scheduleRestAlert(after seconds: TimeInterval, exercise: String) {
        let content = UNMutableNotificationContent()
        content.title = "Recupero finito"
        content.body = "\(exercise): vai con la prossima serie 💪"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restId])
        center.add(UNNotificationRequest(identifier: restId, content: content, trigger: trigger))
    }

    static func cancelRestAlert() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [restId])
        center.removeDeliveredNotifications(withIdentifiers: [restId])
    }

    // MARK: Interval timer

    private static let intervalPrefix = "interval-"

    /// One alert per phase change of the interval timer, replacing any previous ones.
    static func scheduleIntervalAlerts(_ alerts: [(after: TimeInterval, title: String, body: String)]) {
        cancelIntervalAlerts()
        let center = UNUserNotificationCenter.current()
        // iOS keeps at most 64 pending notifications per app.
        for (i, alert) in alerts.prefix(60).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, alert.after), repeats: false)
            center.add(UNNotificationRequest(identifier: intervalPrefix + String(i), content: content, trigger: trigger))
        }
    }

    static func cancelIntervalAlerts() {
        let ids = (0..<60).map { intervalPrefix + String($0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func haptic() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }

    /// Stronger buzz for a phase change of the interval timer.
    static func phaseHaptic() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }

    /// Shows the "rest is over" banner and sound even while the app is open.
    /// Interval alerts only ring: the timer screen already shows the new phase.
    private final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
        static let shared = ForegroundPresenter()

        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            let isInterval = notification.request.identifier.hasPrefix(Platform.intervalPrefix)
            completionHandler(isInterval ? [.sound] : [.banner, .list, .sound])
        }
    }
}
