import SwiftUI

/// Adds or edits a machine or a zone: name, room, cell typed by hand ("C3"), size, colour and photo.
struct MapItemEditor: View {
    let gym: GymStore
    let isNew: Bool
    @State var item: MapItem
    @State var roomId: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var cellText = ""
    @State private var newPhoto: UIImage?
    @State private var photoRemoved = false
    @State private var error: String?
    @State private var confirmDelete = false

    private var shownPhoto: UIImage? { newPhoto ?? (photoRemoved ? nil : gym.photo(item)) }
    private var isZone: Bool { item.kind == .zone }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $item.kind) {
                        Text("Macchinario").tag(MapItem.Kind.machine)
                        Text("Zona").tag(MapItem.Kind.zone)
                    }
                    .pickerStyle(.segmented)
                    TextField(isZone ? "Nome della zona (Pesi liberi)" : "Nome (Panca regolabile)", text: $item.name)
                }

                Section {
                    if gym.map.rooms.count > 1 {
                        Picker("Sala", selection: $roomId) {
                            ForEach(gym.map.rooms) { Text($0.name).tag($0.id) }
                        }
                    }
                    HStack {
                        Text("Cella")
                        Spacer()
                        TextField("C3", text: $cellText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 17, weight: .bold).monospaced())
                            .frame(width: 90)
                    }
                    Stepper("Larghezza: \(cellsText(item.width))", value: $item.width, in: 1...20)
                    Stepper("Altezza: \(cellsText(item.height))", value: $item.height, in: 1...20)
                } header: {
                    Text("Posizione")
                } footer: {
                    Text("Colonna (lettera) e riga (numero) dell'angolo in alto a sinistra: \(previewRange).")
                }

                if isZone {
                    Section("Colore") {
                        HStack(spacing: 14) {
                            ForEach(MapItem.zoneColors.indices, id: \.self) { i in
                                Circle()
                                    .fill(MapItem.zoneColors[i])
                                    .frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Theme.ink, lineWidth: item.color == i ? 3 : 0))
                                    .onTapGesture { item.color = i }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Foto") {
                    PhotoField(current: shownPhoto) { picked in
                        newPhoto = picked
                        photoRemoved = picked == nil
                    }
                }

                if !isNew {
                    let linked = gym.exercises(at: item.id)
                    if !linked.isEmpty {
                        Section("Esercizi collegati") {
                            ForEach(linked, id: \.exercise) { link in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.exercise)
                                    if !link.setting.isEmpty {
                                        Text(link.setting).font(.system(size: 13)).foregroundStyle(Theme.warm)
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Button(isZone ? "Elimina zona" : "Elimina macchinario", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? "Nuovo" : item.name)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if let error {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(hex: 0xFF5A5F), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save)
                        .disabled(item.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Eliminare \(item.name)? Anche gli esercizi collegati perderanno il collegamento.",
                                isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    gym.remove(item.id)
                    dismiss()
                }
            }
            .onAppear { cellText = item.cell }
            .onChange(of: cellText) { error = nil }
            .onChange(of: item.width) { error = nil }
            .onChange(of: item.height) { error = nil }
        }
    }

    private func cellsText(_ n: Int) -> String { n == 1 ? "1 cella" : "\(n) celle" }

    private var previewRange: String {
        guard let cell = MapItem.parseCell(cellText) else { return "es. C3" }
        var copy = item
        copy.column = cell.column
        copy.row = cell.row
        return copy.cellRange
    }

    private func save() {
        guard let cell = MapItem.parseCell(cellText) else {
            error = "Scrivi la cella come lettera + numero, per esempio C3"
            return
        }
        var final = item
        final.name = item.name.trimmingCharacters(in: .whitespaces)
        final.column = cell.column
        final.row = cell.row

        let oldPhoto = item.photo
        if let newPhoto {
            final.photo = gym.savePhoto(newPhoto)
        } else if photoRemoved {
            final.photo = nil
        }

        if let problem = gym.put(final, in: roomId) {
            // Not placed: drop the photo just saved, keep the old one.
            if let saved = final.photo, saved != oldPhoto { gym.deletePhoto(saved) }
            error = problem
            return
        }
        if let oldPhoto, oldPhoto != final.photo { gym.deletePhoto(oldPhoto) }
        dismiss()
    }
}

#Preview {
    let gym = PreviewData.gym()
    let room = gym.map.rooms[0]
    return MapItemEditor(gym: gym, isNew: false, item: room.items[1], roomId: room.id)
        .preferredColorScheme(.dark)
}
