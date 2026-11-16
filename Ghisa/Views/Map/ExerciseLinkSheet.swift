import SwiftUI

/// Chooses where an exercise is done and how the machine is set up for it.
/// The link is kept by exercise name, so it is the same in every sheet and month.
struct ExerciseLinkSheet: View {
    let gym: GymStore
    /// Exercise name as written by the coach.
    let exercise: String
    /// Exercise name as shown in the app.
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?
    @State private var setting = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Schienale 30°, sedile 4, presa larga…", text: $setting, axis: .vertical)
                } header: {
                    Text("Come si imposta")
                }

                if gym.map.rooms.allSatisfy(\.items.isEmpty) {
                    Section {
                        Text("La mappa è ancora vuota: aggiungi i macchinari dalla card \"Mappa palestra\" nella home.")
                            .foregroundStyle(Theme.muted)
                    }
                }

                ForEach(gym.map.rooms) { room in
                    if !room.items.isEmpty {
                        Section(room.name) {
                            ForEach(sorted(room.items)) { item in
                                Button { selected = item.id } label: { row(item) }
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }

                if gym.link(for: exercise) != nil {
                    Section {
                        Button("Scollega", role: .destructive) {
                            gym.setLink(exercise, title: title, item: nil, setting: "")
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        gym.setLink(exercise, title: title, item: selected, setting: setting)
                        dismiss()
                    }
                    .disabled(selected == nil)
                }
            }
            .onAppear {
                guard let current = gym.link(for: exercise) else { return }
                selected = current.item.id
                setting = current.link.setting
            }
        }
    }

    /// Machines first, then zones, by name.
    private func sorted(_ items: [MapItem]) -> [MapItem] {
        items.sorted { ($0.kind == .zone ? 1 : 0, $0.name) < ($1.kind == .zone ? 1 : 0, $1.name) }
    }

    private func row(_ item: MapItem) -> some View {
        HStack(spacing: 12) {
            PhotoThumb(image: gym.photo(item), size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                Text(item.kind == .zone ? "Zona · \(item.cellRange)" : item.cellRange)
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if selected == item.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).font(.system(size: 20))
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ExerciseLinkSheet(gym: PreviewData.gym(), exercise: "PANCA PIANA", title: "Panca Piana")
        .preferredColorScheme(.dark)
}
