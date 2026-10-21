import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var manager: ParkingManager
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                if manager.authorization != .authorizedAlways {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Autorisation « Toujours » requise")
                                .font(.headline)
                            Text("Pour détecter ton arrivée même quand l'app est fermée, autorise la localisation « Toujours » et les notifications.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if manager.authorization == .denied || manager.authorization == .restricted {
                                Button("Ouvrir les Réglages") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            } else {
                                Button("Autoriser") { manager.requestPermissions() }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Adresses surveillées") {
                    if manager.spots.isEmpty {
                        Text("Aucune adresse. Appuie sur + pour en ajouter une.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(manager.spots) { spot in
                        SpotRow(spot: spot)
                    }
                    .onDelete { offsets in
                        offsets.map { manager.spots[$0] }.forEach(manager.remove)
                    }
                }
            }
            .navigationTitle("Parking")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showAdd) {
                AddSpotView()
            }
            .onAppear {
                if manager.authorization == .notDetermined { manager.requestPermissions() }
            }
        }
    }
}

struct SpotRow: View {
    @EnvironmentObject var manager: ParkingManager
    let spot: ParkingSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(spot.name).font(.headline)
                Spacer()
                if manager.isActive(spot) {
                    Text("Sur place")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2), in: Capsule())
                }
            }
            Text(spot.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Rayon : \(Int(spot.radius)) m")
                .font(.caption)
                .foregroundStyle(.secondary)
            if manager.isActive(spot) {
                Button("Arrêter les rappels pour aujourd'hui", role: .destructive) {
                    manager.stopReminders(for: spot)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddSpotView: View {
    @EnvironmentObject var manager: ParkingManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var radius: Double = 150
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom (ex : Bureau)", text: $name)
                    TextField("Adresse complète", text: $address, axis: .vertical)
                        .textContentType(.fullStreetAddress)
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Rayon de détection : \(Int(radius)) m")
                        Slider(value: $radius, in: 100...500, step: 25)
                    }
                } footer: {
                    Text("150 m est un bon compromis. Plus petit, iOS risque de rater ton arrivée.")
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nouvelle adresse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Ajouter") { save() }
                            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await manager.addSpot(name: name, address: address, radius: radius)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
