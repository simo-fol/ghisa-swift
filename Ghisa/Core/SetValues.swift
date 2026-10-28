import Foundation

/// Helpers for the free text the log book uses: "15-20-22.5", "12,5-5", "3 X 7/9", "REST 60\"".
enum SetValues {
    private static let decimalComma = try! NSRegularExpression(pattern: #"(\d),(\d)"#)
    private static let dashSeparator = try! NSRegularExpression(pattern: #"\s*-+\s*"#)
    private static let spaceSeparator = try! NSRegularExpression(pattern: #"\s+"#)
    private static let repsList = try! NSRegularExpression(pattern: #"^\d+(\s*-\s*\d+)*$"#)
    private static let digits = try! NSRegularExpression(pattern: #"\d+"#)
    private static let restPattern = try! NSRegularExpression(pattern: #"REST[^\d]*(\d{2,3})"#, options: .caseInsensitive)
    private static let leadingNumber = try! NSRegularExpression(pattern: #"^\s*\d+(\.\d+)?"#)

    /// Splits a cell such as "15-20-22,5" or "12 15 17.5" into one value per set.
    static func split(_ text: String) -> [String] {
        let normalized = replace(decimalComma, in: text, with: "$1.$2")
        // "20 (facili) -12.5" uses dashes; "12 15 17.5" only spaces.
        let separator = normalized.contains("-") ? dashSeparator : spaceSeparator
        let ns = normalized as NSString
        var parts: [String] = []
        var start = 0
        for m in separator.matches(in: normalized, range: NSRange(location: 0, length: ns.length)) {
            parts.append(ns.substring(with: NSRange(location: start, length: m.range.location - start)))
            start = m.range.location + m.range.length
        }
        parts.append(ns.substring(from: start))
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// Joins per-set values the way they are written in the sheet: "15-20-22.5".
    static func join(_ values: [String]) -> String {
        values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".") }
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    /// Per-set reps target when the goal is a plain list such as "10-8-6-6" or "15"; empty otherwise.
    static func targetReps(_ goal: String) -> [String] {
        let g = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        return firstMatch(repsList, in: g) != nil ? split(g) : []
    }

    /// Number of sets from the "Sets" column ("3", "3-4", "4").
    static func setCount(_ sets: String, fallback: Int = 3) -> Int {
        let ns = sets as NSString
        let numbers = digits.matches(in: sets, range: NSRange(location: 0, length: ns.length))
            .compactMap { Int(ns.substring(with: $0.range)) }
            .filter { $0 > 0 && $0 <= 10 }
        return numbers.max() ?? fallback
    }

    /// Rest time read from a coach note such as "REST 60\"" or "REST BREVI (60\")".
    static func restSeconds(_ note: String) -> Int? {
        guard let m = firstMatch(restPattern, in: note) else { return nil }
        return Int((note as NSString).substring(with: m.range(at: 1)))
    }

    /// Adds a step to the leading number of a value ("22.5" + 2.5 = "25"), keeping any suffix.
    static func bump(_ value: String, _ step: Double) -> String {
        let normalized = value.replacingOccurrences(of: ",", with: ".")
        guard let m = firstMatch(leadingNumber, in: normalized) else {
            return step > 0 ? format(step) : ""
        }
        let ns = normalized as NSString
        let current = Double(ns.substring(with: m.range).trimmingCharacters(in: .whitespaces)) ?? 0
        let next = max(0, current + step)
        return format(next) + (value as NSString).substring(from: m.range.length)
    }

    /// Same as .NET "0.##".
    static func format(_ value: Double) -> String {
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    private static func firstMatch(_ regex: NSRegularExpression, in s: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length))
    }

    private static func replace(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length),
                                       withTemplate: template)
    }
}
