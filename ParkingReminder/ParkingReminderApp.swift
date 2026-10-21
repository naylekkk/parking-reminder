import SwiftUI
import UserNotifications

@main
struct ParkingReminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ParkingManager.shared)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Important : on crée le gestionnaire de localisation dès le lancement.
        // Quand iOS relance l'app en arrière-plan parce que tu entres/sors d'une zone,
        // c'est lui qui reçoit l'événement.
        _ = ParkingManager.shared
        return true
    }

    // Affiche aussi les notifications quand l'app est ouverte
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
