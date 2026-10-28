import Foundation

/// Reads the coach's log book layout: "MICROCICLO n" blocks, each with
/// "SPLIT X" columns side by side (Esercizio, Note, Rep Goal, Sets, then Carico/Reps per week).
enum WorkbookParser {
    struct Key: Hashable {
        let row: Int
        let col: Int
    }

    static func parse(_ pkg: XlsxPackage) -> [TrainingProtocol] {
        pkg.sheets.map(parseSheet).filter { !$0.microcycles.isEmpty }
    }

    static func parseSheet(_ sheet: XlsxSheet) -> TrainingProtocol {
        let list = sheet.cells()
        var cells: [Key: XlsxCell] = [:]
        for c in list { cells[Key(row: c.row, col: c.col)] = c }
        func text(_ row: Int, _ col: Int) -> String { cells[Key(row: row, col: col)]?.text ?? "" }
        func below(_ label: String) -> String? {
            list.filter { $0.text.uppercased() == label }
                .map { text($0.row + 1, $0.col) }
                .first { !$0.isEmpty }
        }

        let proto = TrainingProtocol(sheetName: sheet.name,
                                startLabel: below("INIZIO PROTOCOLLO"),
                                coach: below("PERSONAL COACH"))

        let microRows = list.filter { $0.text.uppercased().hasPrefix("MICROCICLO") }.sorted { $0.row < $1.row }
        let maxRow = list.map(\.row).max() ?? 0

        for (i, micro) in microRows.enumerated() {
            let start = micro.row
            let end = i + 1 < microRows.count ? microRows[i + 1].row : maxRow + 1
            let number = Int(String(micro.text.filter(\.isNumber))) ?? i + 1
            let microcycle = Microcycle(number: number)

            let splitCells = list
                .filter { $0.row > start && $0.row < end && $0.text.uppercased().hasPrefix("SPLIT") }
                .sorted { $0.col < $1.col }
            guard let first = splitCells.first else { continue }
            let splitRow = first.row
            let headerRow = splitRow + 1
            let lastCol = list.filter { $0.row == headerRow }.map(\.col).max() ?? 0

            for (s, split) in splitCells.enumerated() {
                let from = split.col
                let to = s + 1 < splitCells.count ? splitCells[s + 1].col - 1 : lastCol
                if let block = parseBlock(split.text, from, to, splitRow, headerRow, end, text) {
                    microcycle.splits.append(block)
                }
            }
            proto.microcycles.append(microcycle)
        }
        return proto
    }

    static func parseBlock(_ title: String, _ from: Int, _ to: Int, _ splitRow: Int, _ headerRow: Int, _ end: Int,
                           _ text: (Int, Int) -> String) -> SplitBlock? {
        var nameCol: Int?, noteCol: Int?, goalCol: Int?, setsCol: Int?
        var loads: [Int] = []
        if from <= to {
            for col in from...to {
                switch text(headerRow, col).uppercased() {
                case "ESERCIZIO": nameCol = col
                case "NOTE": noteCol = col
                case "REP GOAL": goalCol = col
                case "SETS": setsCol = col
                case "CARICO": loads.append(col)
                default: break
                }
            }
        }
        guard let nameCol, !loads.isEmpty else { return nil }

        let letter = String(title.dropFirst(5)).replacingOccurrences(of: "/", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let block = SplitBlock(
            letter: letter.isEmpty ? title : letter,
            weekLabels: loads.enumerated().map { i, c in
                let label = text(splitRow, c)
                return label.isEmpty ? "SET \(Slot.roman[min(i, Slot.roman.count - 1)])" : label
            })
        if headerRow + 1 < end {
            for row in (headerRow + 1)..<end {
                let name = text(row, nameCol)
                if name.isEmpty { continue }
                block.exercises.append(ExerciseRow(
                    row: row,
                    name: name,
                    note: noteCol.map { text(row, $0) } ?? "",
                    repGoal: goalCol.map { text(row, $0) } ?? "",
                    sets: setsCol.map { text(row, $0) } ?? "",
                    weeks: loads.map { c in
                        WeekCell(loadRef: CellRef.build(row, c), repsRef: CellRef.build(row, c + 1),
                                 load: text(row, c), reps: text(row, c + 1))
                    }))
            }
        }
        return block
    }
}
