import Foundation

/// A small coach sheet built in memory, so the Xcode Canvas can show every screen.
enum PreviewData {
    static var book: LogBook { try! LogBook.load(workbook()) }

    /// App with the sample sheet loaded, on the home page.
    static func app() -> AppModel { AppModel(previewBook: book) }

    /// App without a sheet: the welcome page.
    static func emptyApp() -> AppModel { AppModel(previewBook: nil) }

    /// Workout on the next session of split A, with the first set already done.
    static func workout() -> WorkoutModel {
        let app = app()
        let proto = app.book!.protocols[0]
        let model = WorkoutModel(app: app, protocolIndex: 0, split: "A", slot: SessionPlanner.nextSlot(proto, "A"),
                                 draft: nil)
        model.toggleDone(model.exercises[0].sets[0], in: model.exercises[0])
        return model
    }

    static let done = DoneSummary(title: "Split A completato", slotLabel: "Microciclo 1 · Settimana II",
                                  recorded: 3, total: 3, minutes: 52, savedToOriginal: true)

    // MARK: Workbook

    private static func workbook() -> Data {
        var cells: [(Int, Int, String)] = [
            (1, 2, "INIZIO PROTOCOLLO"), (2, 2, "MARZO"),
            (1, 5, "PERSONAL COACH"), (2, 5, "Luca"),
            (4, 2, "MICROCICLO 1"),
        ]
        let splits: [(String, Int, [(String, String, String, String)])] = [
            ("A", 2, [("PANCA PIANA", "REST 60\"", "10-8-6-6", "4"),
                      ("LAT MACHINE PRESA LARGA", "", "3 X 8/10", "3"),
                      ("CURL BILANCIERE", "rest brevi (45\")", "12", "3")]),
            ("B", 15, [("SQUAT", "REST 120\"", "8-6-6", "3"),
                       ("LEG PRESS", "", "12-10-10", "3")]),
        ]
        for (letter, col, exercises) in splits {
            cells.append((5, col, "SPLIT \(letter)"))
            for (i, head) in ["ESERCIZIO", "NOTE", "REP GOAL", "SETS"].enumerated() { cells.append((6, col + i, head)) }
            for w in 0..<4 {
                cells.append((5, col + 4 + w * 2, "SET \(Slot.roman[w])"))
                cells.append((6, col + 4 + w * 2, "CARICO"))
                cells.append((6, col + 5 + w * 2, "REPS"))
            }
            for (r, e) in exercises.enumerated() {
                let row = 7 + r
                cells += [(row, col, e.0), (row, col + 1, e.1), (row, col + 2, e.2), (row, col + 3, e.3)]
                // Week I already done.
                cells += [(row, col + 4, "20-22.5-25"), (row, col + 5, "10-8-8")]
            }
        }

        var rows: [Int: [(Int, String)]] = [:]
        for (r, c, text) in cells where !text.isEmpty { rows[r, default: []].append((c, text)) }
        let sheetRows = rows.keys.sorted().map { r in
            let cs = rows[r]!.sorted { $0.0 < $1.0 }.map { c, text in
                "<c r=\"\(CellRef.build(r, c))\" t=\"inlineStr\"><is><t>\(XmlNode.escape(text, quotes: false))</t></is></c>"
            }.joined()
            return "<row r=\"\(r)\">\(cs)</row>"
        }.joined()

        let main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let pkg = "http://schemas.openxmlformats.org/package/2006/relationships"
        let files = [
            ("[Content_Types].xml", """
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
            </Types>
            """),
            ("_rels/.rels", "<Relationships xmlns=\"\(pkg)\"><Relationship Id=\"rId1\" Type=\"\(rel)/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"),
            ("xl/workbook.xml", "<workbook xmlns=\"\(main)\" xmlns:r=\"\(rel)\"><sheets><sheet name=\"MARZO\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>"),
            ("xl/_rels/workbook.xml.rels", "<Relationships xmlns=\"\(pkg)\"><Relationship Id=\"rId1\" Type=\"\(rel)/worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>"),
            ("xl/worksheets/sheet1.xml", "<worksheet xmlns=\"\(main)\"><sheetData>\(sheetRows)</sheetData></worksheet>"),
        ]
        return Zip.write(files.map { Zip.Entry(name: $0.0, data: Data($0.1.utf8)) })
    }
}
