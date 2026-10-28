import Foundation

/// Minimal .xlsx reader/writer. Reads cell values and rewrites only the values of
/// the cells we touch, so formatting, merged cells and images stay intact.
final class XlsxPackage {
    private var entries: [Zip.Entry] = []
    private var sharedStrings: [String] = []
    private var xfNumFmt: [Int] = []
    private var numFmts: [Int: String] = [:]

    private(set) var sheets: [XlsxSheet] = []

    static func load(_ data: Data) throws -> XlsxPackage {
        let pkg = XlsxPackage()
        pkg.entries = try Zip.read(data)
        try pkg.readSharedStrings()
        try pkg.readStyles()
        try pkg.readSheets()
        return pkg
    }

    func save() -> Data {
        let out = entries.map { entry -> Zip.Entry in
            guard let sheet = sheets.first(where: { $0.path == entry.name && $0.isDirty }) else { return entry }
            return Zip.Entry(name: entry.name, data: sheet.document.xmlData())
        }
        for sheet in sheets { sheet.isDirty = false }
        return Zip.write(out)
    }

    private func entry(_ name: String) -> Data? { entries.first { $0.name == name }?.data }

    private func readSharedStrings() throws {
        guard let data = entry("xl/sharedStrings.xml") else { return }
        for si in try XmlNode.parse(data).elements("si") {
            sharedStrings.append(si.descendants("t").map(\.value).joined())
        }
    }

    private func readStyles() throws {
        guard let data = entry("xl/styles.xml") else { return }
        let root = try XmlNode.parse(data)
        for f in root.element("numFmts")?.elements("numFmt") ?? [] {
            if let id = f.attribute("numFmtId").flatMap(Int.init), let code = f.attribute("formatCode") {
                numFmts[id] = code
            }
        }
        for xf in root.element("cellXfs")?.elements("xf") ?? [] {
            xfNumFmt.append(xf.attribute("numFmtId").flatMap(Int.init) ?? 0)
        }
    }

    private func readSheets() throws {
        guard let wbData = entry("xl/workbook.xml"), let relData = entry("xl/_rels/workbook.xml.rels") else {
            throw Zip.Failure.corrupt("workbook")
        }
        let wb = try XmlNode.parse(wbData)
        var rels: [String: String] = [:]
        for r in try XmlNode.parse(relData).elements("Relationship") {
            if let id = r.attribute("Id"), let target = r.attribute("Target") { rels[id] = target }
        }
        var result: [XlsxSheet] = []
        for s in wb.element("sheets")?.elements("sheet") ?? [] {
            guard let rid = s.attribute(local: "id", prefixed: true), let target = rels[rid] else { continue }
            let path = target.hasPrefix("/") ? String(target.drop { $0 == "/" }) : "xl/" + target
            guard let data = entry(path) else { continue }
            result.append(try XlsxSheet(package: self, name: s.attribute("name") ?? "", path: path,
                                        document: XmlNode.parse(data)))
        }
        sheets = result
    }

    func cellText(_ c: XmlNode) -> String {
        let type = c.attribute("t")
        let v = c.element("v")?.value
        switch type {
        case "s":
            guard let i = v.flatMap(Int.init), i >= 0, i < sharedStrings.count else { return "" }
            return sharedStrings[i]
        case "inlineStr":
            return c.element("is")?.descendants("t").map(\.value).joined() ?? ""
        case "str", "e":
            return v ?? ""
        case "b":
            return v == "1" ? "TRUE" : "FALSE"
        default:
            break
        }
        guard let v, !v.isEmpty else { return "" }
        guard let number = Double(v.trimmingCharacters(in: .whitespaces)) else { return v }
        let style = c.attribute("s").flatMap(Int.init) ?? 0
        let fmtId = style >= 0 && style < xfNumFmt.count ? xfNumFmt[style] : 0
        guard let code = dateFormatCode(fmtId) else { return Self.formatNumber(number) }
        return DateText.format(number, code)
    }

    private func dateFormatCode(_ fmtId: Int) -> String? {
        if (14...22).contains(fmtId) { return "d/m/yyyy" }
        guard let code = numFmts[fmtId] else { return nil }
        let plain = String(code.filter { $0 != "\\" && $0 != "\"" }).lowercased()
        return plain.contains("d") || plain.contains("y") ? plain : nil
    }

    /// Same as .NET "0.###": up to three decimals, no trailing zeros.
    static func formatNumber(_ n: Double) -> String {
        var s = String(format: "%.3f", n)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s == "-0" ? "0" : s
    }
}

struct XlsxCell {
    let row: Int
    let col: Int
    let ref: String
    let text: String
}

final class XlsxSheet {
    private unowned let package: XlsxPackage
    private let sheetData: XmlNode
    let name: String
    let path: String
    let document: XmlNode
    var isDirty = false

    init(package: XlsxPackage, name: String, path: String, document: XmlNode) throws {
        guard let data = document.element("sheetData") else { throw Zip.Failure.corrupt(path) }
        self.package = package
        self.name = name
        self.path = path
        self.document = document
        sheetData = data
    }

    /// All non-empty cells.
    func cells() -> [XlsxCell] {
        var result: [XlsxCell] = []
        for row in sheetData.elements("row") {
            for c in row.elements("c") {
                guard let r = c.attribute("r") else { continue }
                let text = package.cellText(c).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continue }
                let (rowIdx, colIdx) = CellRef.parse(r)
                result.append(XlsxCell(row: rowIdx, col: colIdx, ref: r, text: text))
            }
        }
        return result
    }

    /// Writes a text value into a cell, keeping its style.
    func setText(_ reference: String, _ text: String) {
        let (rowIdx, colIdx) = CellRef.parse(reference)
        let p = sheetData.prefix
        let rows = sheetData.elements("row")
        let row: XmlNode
        if let existing = rows.first(where: { $0.attribute("r").flatMap(Int.init) == rowIdx }) {
            row = existing
        } else {
            row = XmlNode(element: p + "row", attributes: [("r", String(rowIdx))])
            if let after = rows.last(where: { ($0.attribute("r").flatMap(Int.init) ?? 0) < rowIdx }) {
                sheetData.insert(row, after: after)
            } else {
                sheetData.insert(row, at: 0)
            }
        }
        let cellsInRow = row.elements("c")
        let cell: XmlNode
        if let existing = cellsInRow.first(where: { $0.attribute("r") == reference }) {
            cell = existing
        } else {
            cell = XmlNode(element: p + "c", attributes: [("r", reference)])
            if let after = cellsInRow.last(where: { CellRef.parse($0.attribute("r") ?? "A1").col < colIdx }) {
                row.insert(cell, after: after)
            } else {
                row.insert(cell, at: 0)
            }
        }
        cell.setAttribute("t", nil)
        cell.removeChildren()
        if !text.isEmpty {
            cell.setAttribute("t", "inlineStr")
            let t = XmlNode(element: p + "t", attributes: [("xml:space", "preserve")])
            t.append(XmlNode(text: text))
            let inline = XmlNode(element: p + "is")
            inline.append(t)
            cell.append(inline)
        }
        isDirty = true
    }
}

enum CellRef {
    static func parse(_ reference: String) -> (row: Int, col: Int) {
        var col = 0
        var digits = ""
        for ch in reference {
            if ch.isLetter, digits.isEmpty, let a = ch.uppercased().unicodeScalars.first?.value {
                col = col * 26 + Int(a) - 64
            } else {
                digits.append(ch)
            }
        }
        return (Int(digits) ?? 0, col)
    }

    static func build(_ row: Int, _ col: Int) -> String {
        var letters = ""
        var c = col
        while c > 0 {
            letters = String(UnicodeScalar(UInt8(65 + (c - 1) % 26))) + letters
            c = (c - 1) / 26
        }
        return letters + String(row)
    }
}

/// Excel turns entries like "7/9" (reps range) or "10-8-8" (reps) into dates.
/// This renders those dates back into the text that was originally typed.
enum DateText {
    static func format(_ serial: Double, _ formatCode: String) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let origin = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        let date = calendar.date(byAdding: .day, value: Int(serial.rounded(.down)), to: origin)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year!
        // A year close to "now" was added by Excel itself: it was not typed.
        let typedYear = year < 2020 || year > 2040

        var out = ""
        let code = Array(formatCode.split(separator: ";", omittingEmptySubsequences: false).first ?? "")
        var i = 0
        while i < code.count {
            let ch = code[i]
            var run = 1
            while i + run < code.count, code[i + run] == ch { run += 1 }
            switch ch {
            case "d": out += String(parts.day!)
            case "m": out += String(parts.month!)
            case "y":
                if typedYear {
                    out += String(year % 100)
                } else {
                    while let last = out.last, !last.isNumber { out.removeLast() }
                }
            default: out += String(code[i..<(i + run)])
            }
            i += run
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
