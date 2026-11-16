import Foundation

/// Floor plan of the gym: rooms drawn on an invisible grid, with machines and zones placed in its cells.
struct GymMap: Codable {
    var rooms = [Room(name: "Sala 1")]
    /// Where each exercise is done, by exercise name (see `GymStore.key`).
    var links: [String: ExerciseLink] = [:]
}

/// One room of the gym: a grid of `columns` × `rows` cells (A1 is the top-left one).
struct Room: Codable, Identifiable {
    var id = UUID()
    var name: String
    var columns = 8
    var rows = 12
    var items: [MapItem] = []

    /// Smallest grid that still holds every item.
    var minColumns: Int { max(2, items.map(\.lastColumn).max() ?? 0) }
    var minRows: Int { max(2, items.map(\.lastRow).max() ?? 0) }

    /// The machine that would sit under `item`, if any. Zones can overlap anything.
    func clash(_ item: MapItem) -> MapItem? {
        guard item.kind == .machine else { return nil }
        return items.first { $0.id != item.id && $0.kind == .machine && $0.overlaps(item) }
    }
}

/// A machine or a zone ("Pesi liberi") placed on the grid. It covers `width` × `height` cells
/// starting from (`column`, `row`), both counted from 1.
struct MapItem: Codable, Identifiable {
    enum Kind: String, Codable { case machine, zone }

    var id = UUID()
    var kind = Kind.machine
    var name = ""
    var column = 1
    var row = 1
    var width = 1
    var height = 1
    /// Colour of a zone: index in `MapItem.zoneColors`.
    var color = 0
    /// File name of the photo, in `GymStore.photosDirectory`.
    var photo: String?

    var lastColumn: Int { column + width - 1 }
    var lastRow: Int { row + height - 1 }

    /// "C3"
    var cell: String { CellRef.build(row, column) }

    /// "C3", or "C3:D4" when it covers more cells.
    var cellRange: String {
        width == 1 && height == 1 ? cell : cell + ":" + CellRef.build(lastRow, lastColumn)
    }

    func overlaps(_ other: MapItem) -> Bool {
        column <= other.lastColumn && other.column <= lastColumn && row <= other.lastRow && other.row <= lastRow
    }

    /// "C3" → (column 3, row 3). Nil when the text isn't a cell.
    static func parseCell(_ text: String) -> (column: Int, row: Int)? {
        let clean = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard clean.range(of: #"^[A-Z]{1,2}[0-9]{1,3}$"#, options: .regularExpression) != nil else { return nil }
        let (row, column) = CellRef.parse(clean)
        return row > 0 && column > 0 ? (column, row) : nil
    }

    /// 3 → "C".
    static func columnName(_ column: Int) -> String {
        String(CellRef.build(1, column).dropLast())
    }
}

/// Where an exercise is done and how the machine is set up for it.
struct ExerciseLink: Codable {
    var item: UUID
    /// "Schienale 30°, sedile 4".
    var setting = ""
    /// Exercise name as shown in the app, for the list of exercises of a machine.
    var exercise: String
}
