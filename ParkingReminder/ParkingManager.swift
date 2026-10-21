import Foundation
import CoreLocation
import UserNotifications

struct ParkingSpot: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var radius: Double = 150   // en mètres (iOS est fiable à partir de ~100 m)

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum ParkingError: LocalizedError {
    case addressNotFound
    var errorDescription: String? { "Adresse introuvable. Essaie avec la ville et le code postal." }
}

@MainActor
final class ParkingManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = ParkingManager()

    /// Intervalle entre deux rappels (2 heures). Mets 60 pour tester rapidement.
    static let reminderInterval: TimeInterval = 60   // TEST : 1 min (remettre 2 * 60 * 60)

    @Published private(set) var spots: [ParkingSpot] = []
    @Published private(set) var activeSpotIDs: Set<UUID> = []     // adresses où tu es actuellement
    @Published private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private let spotsKey = "parkingSpots"
    private let activeKey = "activeSpotIDs"

    private override init() {
        super.init()
        locationManager.delegate = self
        authorization = locationManager.authorizationStatus
        load()
        spots.forEach(startMonitoring)
    }

    // MARK: - Autorisations

    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()   // étape 1
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()      // étape 2 : « Toujours »
        default:
            break
        }
    }

    // MARK: - Gestion des adresses

    func addSpot(name: String, address: String, radius: Double) async throws {
        let placemarks = try await CLGeocoder().geocodeAddressString(address)
        guard let location = placemarks.first?.location else { throw ParkingError.addressNotFound }

        let spot = ParkingSpot(
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? address : name,
            address: address,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radius: radius
        )
        spots.append(spot)
        save()
        startMonitoring(spot)
    }

    func remove(_ spot: ParkingSpot) {
        if let region = locationManager.monitoredRegions.first(where: { $0.identifier == spot.id.uuidString }) {
            locationManager.stopMonitoring(for: region)
        }
        cancelReminders(for: spot.id.uuidString)
        activeSpotIDs.remove(spot.id)
        spots.removeAll { $0.id == spot.id }
        save()
    }

    /// Coupe les rappels (ex : tu as payé pour la journée). Ils reprendront à ta prochaine arrivée.
    func stopReminders(for spot: ParkingSpot) {
        cancelReminders(for: spot.id.uuidString)
    }

    func isActive(_ spot: ParkingSpot) -> Bool { activeSpotIDs.contains(spot.id) }

    // MARK: - Géorepérage

    private func startMonitoring(_ spot: ParkingSpot) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        let region = CLCircularRegion(
            center: spot.coordinate,
            radius: min(spot.radius, locationManager.maximumRegionMonitoringDistance),
            identifier: spot.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
        locationManager.requestState(for: region)   // au cas où tu y es déjà
    }

    private func handleEnter(_ id: String) {
        guard let spot = spots.first(where: { $0.id.uuidString == id }),
              !activeSpotIDs.contains(spot.id) else { return }

        activeSpotIDs.insert(spot.id)
        save()

        let center = UNUserNotificationCenter.current()

        // 1) Notification immédiate à l'arrivée
        let arrival = UNMutableNotificationContent()
        arrival.title = "🅿️ Pense à payer le parking"
        arrival.body = "Tu es arrivé à \(spot.name)."
        arrival.sound = .default
        center.add(UNNotificationRequest(identifier: "arrivee-\(id)", content: arrival, trigger: nil))

        // 2) Rappel répété toutes les 2 h — annulé automatiquement quand tu quittes la zone
        let reminder = UNMutableNotificationContent()
        reminder.title = "⏰ Rappel parking"
        reminder.body = "Tu es toujours à \(spot.name). Pense à reprendre un ticket."
        reminder.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.reminderInterval, repeats: true)
        center.add(UNNotificationRequest(identifier: "rappel-\(id)", content: reminder, trigger: trigger))
    }

    private func handleExit(_ id: String) {
        cancelReminders(for: id)
        if let uuid = UUID(uuidString: id) { activeSpotIDs.remove(uuid) }
        save()
    }

    private func cancelReminders(for id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rappel-\(id)"])
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleEnter(id) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleExit(id) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let id = region.identifier
        let inside = (state == .inside)
        let outside = (state == .outside)
        Task { @MainActor in
            if inside { self.handleEnter(id) }
            else if outside, let uuid = UUID(uuidString: id), self.activeSpotIDs.contains(uuid) {
                self.handleExit(id)   // rattrape une sortie qui n'aurait pas été détectée
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            if status == .authorizedWhenInUse {
                self.locationManager.requestAlwaysAuthorization()
            }
            if status == .authorizedAlways {
                self.spots.forEach(self.startMonitoring)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Échec de surveillance pour \(region?.identifier ?? "?") : \(error.localizedDescription)")
    }

    // MARK: - Sauvegarde

    private func save() {
        if let data = try? JSONEncoder().encode(spots) {
            UserDefaults.standard.set(data, forKey: spotsKey)
        }
        UserDefaults.standard.set(activeSpotIDs.map(\.uuidString), forKey: activeKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: spotsKey),
           let saved = try? JSONDecoder().decode([ParkingSpot].self, from: data) {
            spots = saved
        }
        let ids = UserDefaults.standard.stringArray(forKey: activeKey) ?? []
        activeSpotIDs = Set(ids.compactMap(UUID.init(uuidString:)))
    }
}
