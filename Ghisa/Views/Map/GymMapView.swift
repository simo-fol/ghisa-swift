import SwiftUI

/// The gym map: one tab per room, the grid, and the details of the machine you tap.
/// Opened from the home card, or from a workout card with the machine of that exercise highlighted.
struct GymMapView: View {
    @Bindable var gym: GymStore
    /// Item to highlight when the map opens.
    var focus: UUID?
    let close: () -> Void

    @State private var roomId: UUID?
    @State private var editing = false
    @State private var selected: UUID?
    @State private var sheet: MapSheet?
    @State private var photo: PhotoToShow?
    @State private var message: String?

    private var room: Room? { gym.map.rooms.first { $0.id == roomId } ?? gym.map.rooms.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            roomTabs

            if let room {
                MapGrid(room: room, editing: editing, selected: selected,
                        onTapCell: { column, row in tapCell(room, column, row) },
                        onTapItem: { tapItem(room, $0) },
                        onMove: { item, column, row in
                            if let problem = gym.move(item.id, column: column, row: row) {
                                Platform.haptic()
                                message = problem
                            } else {
                                message = nil
                            }
                        })
                    .id(room.id)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            footer
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12))
        .background(Theme.bg.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .animation(.easeOut(duration: 0.2), value: selected)
        .animation(.easeOut(duration: 0.2), value: editing)
        .onAppear {
            guard let focus else { return }
            selected = focus
            roomId = gym.room(of: focus)?.id
        }
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .item(let item, let isNew, let roomId):
                    MapItemEditor(gym: gym, isNew: isNew, item: item, roomId: roomId)
                case .room(let room):
                    RoomEditor(gym: gym, room: room)
                }
            }
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $photo) { PhotoViewer(image: $0.image, title: $0.title) }
    }

    // MARK: Parts

    private var header: some View {
        HStack(spacing: 6) {
            RoundButton(label: "‹", fontSize: 26, background: .clear, action: close)
            Text("Mappa palestra").font(.system(size: 22, weight: .bold))
            Spacer()
            if editing, let room {
                RoundButton(label: "+", fontSize: 22) { addItem(room) }
            }
            Button(editing ? "Fine" : "Modifica") {
                editing.toggle()
                selected = nil
                message = nil
            }
            .buttonStyle(PillButtonStyle(background: editing ? Theme.accent : Theme.surface2,
                                         foreground: editing ? Theme.onAccent : Theme.ink))
        }
    }

    private var roomTabs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(gym.map.rooms) { r in
                    let isCurrent = r.id == room?.id
                    Button(r.name) {
                        if isCurrent, editing {
                            sheet = .room(r)
                        } else {
                            roomId = r.id
                            selected = nil
                        }
                    }
                    .buttonStyle(PillButtonStyle(background: isCurrent ? Theme.accentSoft : Theme.surface2,
                                                 foreground: isCurrent ? Theme.accent : Theme.ink))
                }
                if editing {
                    Button("+ Sala") { roomId = gym.addRoom() }.buttonStyle(PillButtonStyle())
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private var footer: some View {
        if let message {
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.warm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
        } else if editing {
            Text("Tocca una cella vuota per aggiungere · tocca un macchinario per modificarlo · trascinalo per spostarlo · tocca il nome della sala per rinominarla o cambiarne la griglia")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
        } else if let id = selected, let item = gym.item(id) {
            ItemPanel(gym: gym, item: item, close: { selected = nil }) {
                if let image = gym.photo(item) { photo = PhotoToShow(image: image, title: item.name) }
            }
        } else if room?.items.isEmpty ?? true {
            Text("La sala è vuota. Premi Modifica per aggiungere macchinari e zone.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
        }
    }

    // MARK: Actions

    private func tapCell(_ room: Room, _ column: Int, _ row: Int) {
        message = nil
        guard editing else {
            selected = nil
            return
        }
        sheet = .item(MapItem(column: column, row: row), isNew: true, roomId: room.id)
    }

    private func tapItem(_ room: Room, _ item: MapItem) {
        message = nil
        if editing {
            sheet = .item(item, isNew: false, roomId: room.id)
        } else {
            selected = selected == item.id ? nil : item.id
        }
    }

    /// "+" button: a new machine in the first free cell, the cell can be changed in the form.
    private func addItem(_ room: Room) {
        var item = MapItem()
        search: for row in 1...room.rows {
            for column in 1...room.columns {
                item.column = column
                item.row = row
                if room.clash(item) == nil { break search }
            }
        }
        sheet = .item(item, isNew: true, roomId: room.id)
    }
}

/// Details of the tapped item, under the map.
private struct ItemPanel: View {
    let gym: GymStore
    let item: MapItem
    let close: () -> Void
    let showPhoto: () -> Void

    var body: some View {
        let exercises = gym.exercises(at: item.id)

        HStack(alignment: .top, spacing: 14) {
            Button(action: showPhoto) { PhotoThumb(image: gym.photo(item), size: 72) }
                .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text("📍 " + gym.place(of: item)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent)
                Text(item.name).font(.system(size: 18, weight: .bold))
                if exercises.isEmpty {
                    Text(item.kind == .zone ? "Zona" : "Nessun esercizio collegato")
                        .font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                ForEach(exercises, id: \.exercise) { link in
                    (Text(link.exercise).bold() + Text(link.setting.isEmpty ? "" : " · " + link.setting))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            RoundButton(label: "✕", size: 30, fontSize: 13, action: close)
        }
        .card(padding: 14)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private enum MapSheet: Identifiable {
    case item(MapItem, isNew: Bool, roomId: UUID)
    case room(Room)

    var id: UUID {
        switch self {
        case .item(let item, _, _): item.id
        case .room(let room): room.id
        }
    }
}

private struct PhotoToShow: Identifiable {
    let id = UUID()
    let image: UIImage
    let title: String
}

#Preview("Mappa") {
    GymMapView(gym: PreviewData.gym(), close: {})
        .preferredColorScheme(.dark)
}

#Preview("Mappa con Panca evidenziata") {
    let gym = PreviewData.gym()
    return GymMapView(gym: gym, focus: gym.map.rooms[0].items[1].id, close: {})
        .preferredColorScheme(.dark)
}
