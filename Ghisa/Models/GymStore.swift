import Foundation
import Observation
import UIKit

/// Owns the gym map: keeps it on disk (gym-map.json) together with the machine photos.
@Observable
final class GymStore {
    /// Every change is saved right away.
    var map: GymMap { didSet { save() } }

    @ObservationIgnored private let persists: Bool
    @ObservationIgnored private var photoCache: [String: UIImage] = [:]

    private static var fileURL: URL { Platform.stateDirectory.appendingPathComponent("gym-map.json") }
    static var photosDirectory: URL { Platform.stateDirectory.appendingPathComponent("MachinePhotos", isDirectory: true) }

    init() {
        persists = true
        map = (try? Data(contentsOf: Self.fileURL)).flatMap { try? JSONDecoder().decode(GymMap.self, from: $0) }
            ?? GymMap()
    }

    /// In-memory map for Xcode previews.
    init(preview map: GymMap) {
        persists = false
        self.map = map
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: Finding things

    func room(of itemId: UUID) -> Room? {
        map.rooms.first { room in room.items.contains { $0.id == itemId } }
    }

    func item(_ id: UUID) -> MapItem? {
        map.rooms.lazy.compactMap { room in room.items.first { $0.id == id } }.first
    }

    /// "Sala pesi · C3"
    func place(of item: MapItem) -> String {
        [room(of: item.id)?.name, item.cellRange].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: Editing

    /// Adds the item to a room, or updates it (also moving it there from another room).
    /// The room grows when the item goes past its edge. Returns why it can't go there, or nil.
    func put(_ item: MapItem, in roomId: UUID) -> String? {
        guard let r = map.rooms.firstIndex(where: { $0.id == roomId }) else { return "Sala non trovata" }
        var room = map.rooms[r]
        if let other = room.clash(item) {
            return "Si sovrappone a \(other.name.isEmpty ? "un altro macchinario" : other.name) (\(other.cellRange))"
        }
        room.columns = max(room.columns, item.lastColumn)
        room.rows = max(room.rows, item.lastRow)
        if let i = room.items.firstIndex(where: { $0.id == item.id }) {
            room.items[i] = item
        } else {
            room.items.append(item)
        }

        var rooms = map.rooms
        for i in rooms.indices where i != r { rooms[i].items.removeAll { $0.id == item.id } }
        rooms[r] = room
        map.rooms = rooms
        return nil
    }

    /// Moves an item within its room, keeping it inside the grid.
    func move(_ id: UUID, column: Int, row: Int) -> String? {
        guard let room = room(of: id), var item = item(id) else { return nil }
        item.column = min(max(column, 1), max(room.columns - item.width + 1, 1))
        item.row = min(max(row, 1), max(room.rows - item.height + 1, 1))
        return put(item, in: room.id)
    }

    /// Deletes an item with its photo and the exercises linked to it.
    func remove(_ id: UUID) {
        if let photo = item(id)?.photo { deletePhoto(photo) }
        var newMap = map
        for r in newMap.rooms.indices { newMap.rooms[r].items.removeAll { $0.id == id } }
        newMap.links = newMap.links.filter { $0.value.item != id }
        map = newMap
    }

    @discardableResult
    func addRoom() -> UUID {
        let room = Room(name: "Sala \(map.rooms.count + 1)")
        map.rooms.append(room)
        return room.id
    }

    /// Saves name and size of a room; the grid never gets smaller than its items.
    func updateRoom(_ room: Room) {
        guard let r = map.rooms.firstIndex(where: { $0.id == room.id }) else { return }
        var room = room
        room.columns = max(room.columns, room.minColumns)
        room.rows = max(room.rows, room.minRows)
        map.rooms[r] = room
    }

    /// Deletes a room and everything in it. The last room stays.
    func removeRoom(_ id: UUID) {
        guard map.rooms.count > 1, let room = map.rooms.first(where: { $0.id == id }) else { return }
        let ids = Set(room.items.map(\.id))
        room.items.compactMap(\.photo).forEach(deletePhoto)
        var newMap = map
        newMap.rooms.removeAll { $0.id == id }
        newMap.links = newMap.links.filter { !ids.contains($0.value.item) }
        map = newMap
    }

    // MARK: Exercises

    /// Same rule used to match exercises across sheets: only letters and digits, uppercase.
    static func key(_ exercise: String) -> String { SessionPlanner.normalize(exercise) }

    /// Where an exercise is done, if it has been linked to an item that still exists.
    func link(for exercise: String) -> (link: ExerciseLink, item: MapItem)? {
        guard let link = map.links[Self.key(exercise)], let item = item(link.item) else { return nil }
        return (link, item)
    }

    /// Links an exercise to an item, or removes the link when `item` is nil.
    func setLink(_ exercise: String, title: String, item: UUID?, setting: String) {
        let key = Self.key(exercise)
        if let item {
            map.links[key] = ExerciseLink(item: item, setting: setting.trimmingCharacters(in: .whitespacesAndNewlines),
                                          exercise: title)
        } else {
            map.links[key] = nil
        }
    }

    /// Exercises done on an item, by name.
    func exercises(at itemId: UUID) -> [ExerciseLink] {
        map.links.values.filter { $0.item == itemId }.sorted { $0.exercise < $1.exercise }
    }

    // MARK: Photos

    func photo(_ item: MapItem) -> UIImage? {
        guard let name = item.photo else { return nil }
        if let cached = photoCache[name] { return cached }
        let image = UIImage(contentsOfFile: Self.photosDirectory.appendingPathComponent(name).path)
        photoCache[name] = image
        return image
    }

    /// Stores a photo (made smaller) and returns the file name to keep in the item.
    func savePhoto(_ image: UIImage) -> String? {
        guard let data = Self.jpeg(image) else { return nil }
        let name = UUID().uuidString + ".jpg"
        if persists {
            try? FileManager.default.createDirectory(at: Self.photosDirectory, withIntermediateDirectories: true)
            guard (try? data.write(to: Self.photosDirectory.appendingPathComponent(name))) != nil else { return nil }
        }
        photoCache[name] = UIImage(data: data)
        return name
    }

    func deletePhoto(_ name: String) {
        photoCache[name] = nil
        if persists { try? FileManager.default.removeItem(at: Self.photosDirectory.appendingPathComponent(name)) }
    }

    /// Longest side at most 1600 px: plenty for the phone, about 300 KB per photo.
    private static func jpeg(_ image: UIImage, maxSide: CGFloat = 1600) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
